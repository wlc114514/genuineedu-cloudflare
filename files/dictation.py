# -*- coding: utf-8 -*-
"""单词默写小工具，两种模式（窗口底部按钮切换）：
· 释义 → 单词（默认）：显示释义+词性+开头字母提示，输入英文单词
· 单词 → 释义：显示英文单词，输入中文释义（宽松判分：写出任一个义项即算对）
· 单词 → 释义 模式下字面判不出时，自动叫本地 JEV（Jev-Style-0.8B）判「意思是否接近」并显示置信度
提交后自动判对错，答错可反复再试，点"下一个"才公布答案并进入下一题"""
import json
import os
import platform
import queue
import re
import subprocess
import sys
import threading
import time
import tkinter as tk
import urllib.request
from tkinter import messagebox
from math import ceil, exp

# 数据目录：打包成 exe 后取 exe 所在目录（词表文件放 exe 旁边），开发时取脚本目录
if getattr(sys, "frozen", False):
    BASE_DIR = os.path.dirname(sys.executable)
else:
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# 字体适配：Windows 用微软雅黑/Consolas，Mac 用苹方/Menlo
if platform.system() == "Darwin":
    UI_FONT = "PingFang SC"
    MONO_FONT = "Menlo"
else:
    UI_FONT = "Microsoft YaHei"
    MONO_FONT = "Consolas"

# ============================================================
# 单词表：以后把下面列表整体替换成你的词即可
# 每项格式：(单词, 词性, 释义)
# ============================================================
WORDS = [
    # 默认词表为空：所有词通过"加词"按钮录入（保存到 dictation_extra.json）
]


# ============================================================
# 用户自录词表：同目录 dictation_extra.json，启动时自动合并到词表
# （程序里点"加词"录入的新词都存到这里，格式与 WORDS 相同）
# ============================================================
def load_extra_words():
    path = os.path.join(BASE_DIR, "dictation_extra.json")
    try:
        with open(path, encoding="utf-8") as f:
            extra = json.load(f)
    except (OSError, ValueError):
        return []
    known = {w for w, _, _ in WORDS}
    merged = []
    for item in extra:
        if not (isinstance(item, (list, tuple)) and len(item) == 3):
            continue
        w, p, m = item
        if not w or not m or w in known:
            continue
        known.add(w)
        merged.append((w, str(p), str(m)))
    return merged


# 基础词表（内嵌 WORDS 的副本，清空自录词时恢复用）
BASE_WORDS = list(WORDS)
WORDS += load_extra_words()


# 词性匹配：长优先（prep&adv 在 prep/adv 前，n&adj 在 n 前……）
_POS_RE = re.compile(r"\b(?:prep&adv|n&adj|adj&n|n&v|v&n|adj&adv|adj&v|conj|adj|adv|prep|n|v)\b\s*\.?")


def split_pos_meaning(rest):
    """把 'n. 过程 v. 处理' 拆成 (词性, 释义)，与词表解析规则一致"""
    pos_tokens = []
    for m in _POS_RE.finditer(rest):
        t = m.group(0).replace(" ", "")
        if t in ("n", "v", "adj", "adv", "prep", "conj"):
            t += "."
        if t not in pos_tokens:
            pos_tokens.append(t)
    meaning = _POS_RE.sub("", rest).replace("&", " ")
    meaning = re.sub(r"\s+", " ", meaning).strip()
    meaning = re.sub(r"\s+(?=[，。；：、（】])", "", meaning)
    return " ".join(pos_tokens), meaning


def hint_count(word):
    """提示字母数：词长的一半减一，不是整数则向上取整"""
    return ceil(len(word) / 2) - 1


def masked_display(word):
    """开头提示字母原样显示，其余挖空为下划线"""
    n = hint_count(word)
    shown = list(word[:n]) + ["_"] * (len(word) - n)
    return " ".join(shown)


def _norm_cn(s):
    """只保留汉字：去掉标点、空格、字母，供中文释义宽松比对用"""
    return re.sub(r"[^\u4e00-\u9fff]+", "", s)


def meaning_match(ans, meaning):
    """宽松判断用户写的中文释义算不算对：
    完全一致 / 完整写出某个义项 / 覆盖标准释义的一段（≥2 字）/
    或每个字都在标准释义里且长度接近，都算对"""
    a = _norm_cn(ans)
    m = _norm_cn(meaning)
    if not a:
        return False
    if not m:
        # 释义里没有汉字（极少见）：退化为原文比较
        na, nm = ans.strip().lower(), meaning.strip().lower()
        return bool(na) and (na == nm or na in nm)
    if a == m:
        return True
    if len(a) >= 2 and a in m:
        return True
    senses = [s for s in (_norm_cn(x) for x in re.split(r"[,，;；、/]", meaning)) if s]
    for s in senses:
        if a == s:
            return True
        if len(s) >= 2 and s in a:
            return True
        if len(a) >= 2 and a in s:
            return True
    if len(a) >= 2 and all(ch in m for ch in a):
        shortest = min(len(s) for s in senses) if senses else len(m)
        if len(a) * 2 >= shortest:
            return True
    return False


# ============================================================
# 本地 JEV 判分器（llama.cpp + Jev-Style-0.8B-Decision-v3）
# 字面判不出时，问它「学生写的释义与标准释义意思是否一致」，
# 取 yes/no 两个 token 的 logit 差 → 按校准温度算置信度（0-1）。
# 配置文件：同目录 dictation_judge.json（不存在则判分器关闭）
# ============================================================
JUDGE_CFG_PATH = os.path.join(BASE_DIR, "dictation_judge.json")
JEV_TEMPERATURE = 0.8800546821789332   # readout_config.json 里的全局校准温度
JEV_TOKEN_YES = 9542                   # token " yes"
JEV_TOKEN_NO = 874                     # token " no"
JEV_INSTRUCTION = "学生写的释义与标准释义表达的意思是否一致？"
JEV_OPTIONS = [("一致", "意思相同或非常接近"),
               ("不一致", "意思不同或无关")]


def _is_blank(s):
    """没有实义字符（空、纯空格、纯标点）→ 视为空白，不交模型判"""
    return not re.search(r"[0-9A-Za-z\u4e00-\u9fff]", s)


def load_judge_config():
    """读 dictation_judge.json；不存在/格式不对 → 返回 {}（判分器关闭）"""
    try:
        with open(JUDGE_CFG_PATH, encoding="utf-8") as f:
            cfg = json.load(f)
    except (OSError, ValueError):
        return {}
    return cfg if isinstance(cfg, dict) else {}


def _jev_prompt(meaning, ans, k):
    """复刻 Jev-Style 官方 macjev-render-v1 布局，截到第 k 个候选的 '->' 处（因果等价）"""
    opt_strs = ["%s: %s" % (kk, dd) for kk, dd in JEV_OPTIONS]
    head = ("State:\n标准释义：%s\n学生写的释义：%s\n\n"
            "Question [choice]: %s\nOptions:\n%sJudge each option:\n"
            % (meaning, ans, JEV_INSTRUCTION,
               "".join("- %s\n" % o for o in opt_strs)))
    tail = "%s ->" % opt_strs[k]
    if k:
        tail = "%s ->\n%s" % (opt_strs[0], tail)
    return head + tail


class JevJudge:
    """本机 llama-server + 判定调用；懒启动，第一次要用时才拉服务"""

    def __init__(self, cfg):
        self.cfg = cfg
        self.host = cfg.get("host", "127.0.0.1")
        self.port = int(cfg.get("port", 8087))
        self.threshold = float(cfg.get("threshold", 0.7))
        self.timeout = float(cfg.get("timeout_s", 15))
        self.exe = os.path.join(BASE_DIR, cfg["exe"]) if cfg.get("exe") else ""
        self.model = os.path.join(BASE_DIR, cfg["model"]) if cfg.get("model") else ""
        self.proc = None
        self.ok = False
        self._starting = False
        self.cache = {}

    def _health(self):
        try:
            with urllib.request.urlopen("http://%s:%d/health" % (self.host, self.port), timeout=2) as r:
                return json.load(r).get("status") == "ok"
        except Exception:
            return False

    def start_async(self):
        """后台把服务拉起来（已就绪/正在启动则忽略）"""
        if self.ok or self._starting:
            return
        self._starting = True
        threading.Thread(target=self._ensure, daemon=True).start()

    def _ensure(self):
        """端口上已有服务（上次遗留）就直接用；否则拉起 llama-server 等就绪"""
        try:
            if self._health():
                self.ok = True
                return
            if not (self.exe and os.path.exists(self.exe) and os.path.exists(self.model)):
                return
            log = open(os.path.join(BASE_DIR, "jev", "server.log"), "ab")
            flags = 0x08000000 if os.name == "nt" else 0   # CREATE_NO_WINDOW，不弹黑窗
            self.proc = subprocess.Popen(
                [self.exe, "-m", self.model, "--host", self.host, "--port", str(self.port),
                 "-c", "2048", "-t", str(min(8, os.cpu_count() or 4)), "--no-webui"],
                stdout=log, stderr=log, creationflags=flags)
            for _ in range(120):            # 最多等 60 秒加载
                if self._health():
                    self.ok = True
                    return
                time.sleep(0.5)
        except Exception:
            pass
        finally:
            self._starting = False

    def judge(self, meaning, ans):
        """返回 (p, err)：p=「意思接近」概率；err 非空表示判分不可用"""
        if _is_blank(ans):
            return 0.0, ""          # 空白直接 0 分，不给模型「撞运气」的机会
        key = (meaning, ans)
        if key in self.cache:
            return self.cache[key], ""
        if not self.ok:
            self.start_async()
            for _ in range(90):             # 等启动，最多 ~45 秒
                if self.ok:
                    break
                time.sleep(0.5)
            if not self.ok:
                return None, "判分服务不可用"
        d = []
        for k in (0, 1):
            try:
                body = {"prompt": _jev_prompt(meaning, ans, k), "n_predict": 1, "temperature": 0,
                        "n_probs": 32, "cache_prompt": False}
                req = urllib.request.Request(
                    "http://%s:%d/completion" % (self.host, self.port),
                    json.dumps(body).encode(), {"Content-Type": "application/json"})
                with urllib.request.urlopen(req, timeout=self.timeout) as r:
                    out = json.load(r)
                lp = {}
                cp = out.get("completion_probabilities") or []
                for e in (cp[0].get("top_logprobs") or []) if cp else []:
                    lp[e.get("id")] = e.get("logprob")
                if JEV_TOKEN_YES not in lp or JEV_TOKEN_NO not in lp:
                    return None, "模型返回缺 yes/no 概率"
                d.append(lp[JEV_TOKEN_YES] - lp[JEV_TOKEN_NO])
            except Exception as e:
                return None, "判分请求失败: %s" % e
        z = (d[0] - d[1]) / JEV_TEMPERATURE
        z = max(-30.0, min(30.0, z))
        p = 1.0 / (1.0 + exp(-z))
        self.cache[key] = p
        return p, ""

    def close(self):
        if self.proc and self.proc.poll() is None:
            try:
                self.proc.terminate()
                self.proc.wait(timeout=5)
            except Exception:
                try:
                    self.proc.kill()
                except Exception:
                    pass


class DictationApp:
    def __init__(self, root):
        self.root = root
        root.title("单词默写")
        root.geometry("640x600")
        root.configure(bg="white")

        self.total = len(WORDS)
        self.round = 1                          # 当前轮次
        self.queue = list(range(self.total))    # 本轮词序（WORDS 索引）
        self.round_words = list(range(self.total))  # 本轮起始词序（重开时恢复用）
        self.pos = 0                            # 本轮进行到第几个
        self.wrong = []                         # 本轮错词索引（按出错顺序）
        self.phase = "normal"  # normal=答题中 correct=答对 wrong=答错可再试 revealed=已看答案
        self.mode = "cn2en"    # cn2en=看释义写单词（默认） en2cn=看单词写释义

        self.progress = tk.Label(root, text="", bg="white",
                                 font=(UI_FONT, 12), fg="gray")
        self.progress.pack(pady=(16, 4))

        self.pos_label = tk.Label(root, text="", bg="white",
                                  font=(UI_FONT, 12), fg="gray")
        self.pos_label.pack(pady=(8, 0))

        self.meaning = tk.Label(root, text="", bg="white",
                                font=(UI_FONT, 20, "bold"),
                                fg="#222", wraplength=500)
        self.meaning.pack(pady=4)

        self.masked = tk.Label(root, text="", bg="white",
                               font=(MONO_FONT, 20, "bold"), fg="#0055cc")
        self.masked.pack(pady=6)

        self.result_label = tk.Label(root, text="", bg="white",
                                     font=(UI_FONT, 16, "bold"))
        self.result_label.pack(pady=6)

        self.entry = tk.Entry(root, font=(MONO_FONT, 18), justify="center")
        self.entry.pack(pady=8, ipady=4)
        self.entry.bind("<Return>", self.submit)

        self.btns = tk.Frame(root, bg="white")
        self.btns.pack(pady=10)
        self.btn_submit = tk.Button(self.btns, text="提交", command=self.submit,
                                    width=8, font=(UI_FONT, 12), bg="#e3f2fd")
        self.btn_submit.grid(row=0, column=0, padx=6)
        self.btn_dont = tk.Button(self.btns, text="不知道", command=self.dont_know,
                                  width=8, font=(UI_FONT, 12), bg="#fff8e1")
        self.btn_dont.grid(row=0, column=1, padx=6)
        self.btn_next = tk.Button(self.btns, text="下一个", command=self.next_word,
                                  width=8, font=(UI_FONT, 12),
                                  bg="#c8e6c9", takefocus=False)
        self.btn_next.grid(row=0, column=1, padx=6)
        self.btn_next.grid_remove()
        self.btn_restart = tk.Button(self.btns, text="重开", command=self.restart,
                                     width=8, font=(UI_FONT, 12), bg="#e8eaf6")
        self.btn_restart.grid(row=0, column=2, padx=6)
        self.btn_add = tk.Button(self.btns, text="加词", command=self.add_words,
                                 width=8, font=(UI_FONT, 12), bg="#ede7f6")
        self.btn_add.grid(row=1, column=0, columnspan=3, sticky="we", pady=(8, 0))
        self.btn_mode = tk.Button(self.btns, text=self.mode_text(), command=self.toggle_mode,
                                  font=(UI_FONT, 12), bg="#fce4ec")
        self.btn_mode.grid(row=2, column=0, columnspan=3, sticky="we", pady=(8, 0))

        # —— 错词预览页（错词轮开始前列出全部错词）——
        self.preview = tk.Frame(root, bg="white")
        self.preview_title = tk.Label(self.preview, bg="white",
                                      font=(UI_FONT, 14, "bold"), fg="#b71c1c")
        self.preview_title.pack(pady=(10, 4))
        self.preview_text = tk.Text(self.preview, font=(UI_FONT, 11),
                                    width=58, height=10, relief="solid", bd=1)
        sb = tk.Scrollbar(self.preview, command=self.preview_text.yview)
        self.preview_text.configure(yscrollcommand=sb.set)
        sb.pack(side=tk.RIGHT, fill=tk.Y)
        self.preview_text.pack(fill=tk.BOTH, expand=True, padx=10)
        self.btn_row = tk.Frame(self.preview, bg="white")
        self.btn_start_round = tk.Button(self.btn_row, text="开始默写", command=self.start_round,
                                         width=12, font=(UI_FONT, 12), bg="#c8e6c9")
        self.btn_start_round.pack(side=tk.LEFT, padx=6)
        self.btn_restart_pv = tk.Button(self.btn_row, text="重新开始", command=self.restart,
                                        width=12, font=(UI_FONT, 12), bg="#e8eaf6")
        self.btn_restart_pv.pack(side=tk.LEFT, padx=6)
        self.btn_row.pack(pady=(4, 12))
        self.preview.pack_forget()  # 初始隐藏

        # —— 本地 JEV 判分器（配置见 dictation_judge.json；不存在则自动关闭）——
        self.judge = None
        self.judge_seq = 0
        self._judge_q = queue.Queue()     # 判分线程 → 主线程的结果回传
        _jcfg = load_judge_config()
        if _jcfg.get("enabled"):
            self.judge = JevJudge(_jcfg)
        self.root.protocol("WM_DELETE_WINDOW", self.on_close)
        self.root.after(120, self._poll_judge)

        self.next_word()

    def submit(self, event=None):
        """提交答案：程序自动比对。答错不公布答案，可再试。
        只有"下一个"按钮时（答对/看完答案后），Enter 直接进入下一词"""
        if self.phase in ("correct", "revealed"):
            self.next_word()
            return
        if self.phase not in ("normal", "wrong"):
            return
        word, _, meaning = WORDS[self.queue[self.pos - 1]]
        ans = self.entry.get().strip()
        ok = meaning_match(ans, meaning) if self.mode == "en2cn" else ans.lower() == word.lower()
        if ok:
            self.result_label.config(text="答对了！", fg="green")
            self.entry.delete(0, tk.END)
            self.entry.focus_set()
            self.phase = "correct"
            self.btn_submit.grid_remove()
            self.btn_dont.grid_remove()
            self.btn_next.grid()
        else:
            if self.mode == "en2cn" and self.judge is not None and not _is_blank(ans):
                self.start_judge(ans, meaning)   # 字面判不出 → 本地 JEV 判「接近吗」；空白不交模型
            else:
                self.result_label.config(text="答错了，再试一次", fg="red")
                self.phase = "wrong"
                self.btn_dont.grid_remove()
                self.btn_next.grid()  # 提交按钮保留，可改答案再提交
                self.entry.focus_set()

    def dont_know(self):
        """不知道：直接显示原词，看完点"下一个"继续。该词记入错词"""
        widx = self.queue[self.pos - 1]
        if widx not in self.wrong:
            self.wrong.append(widx)
        word, _, meaning = WORDS[widx]
        shown = ("释义：" + meaning) if self.mode == "en2cn" else ("原词：" + word)
        self.result_label.config(text=shown, fg="red")
        self.entry.delete(0, tk.END)
        self.entry.focus_set()
        self.phase = "revealed"
        self.btn_submit.grid_remove()
        self.btn_dont.grid_remove()
        self.btn_next.grid()

    def show_preview(self):
        """本轮结束：列出全部错词，用户过一遍后点"开始默写"进入错词轮"""
        for w in (self.pos_label, self.meaning, self.masked,
                  self.result_label, self.entry, self.btns):
            w.pack_forget()
        self.preview_text.config(state="normal")
        self.preview_text.delete("1.0", tk.END)
        for widx in self.preview_words:
            w, p, m = WORDS[widx]
            self.preview_text.insert(tk.END, "%s  [%s]  %s\n" % (w, p, m))
        self.preview_text.config(state="disabled")
        self.preview_title.config(text="本轮错词 %d 个，过一遍再开始" % len(self.preview_words))
        self.preview.pack(fill=tk.BOTH, expand=True, padx=16, pady=8)

    def start_round(self):
        """看完错词列表，开始错词轮"""
        self.preview.pack_forget()
        self.pos_label.pack(pady=(8, 0))
        self.meaning.pack(pady=4)
        self.masked.pack(pady=6)
        self.result_label.pack(pady=6)
        self.entry.pack(pady=8, ipady=4)
        self.btns.pack(pady=10)
        self.round += 1
        self.queue = list(self.preview_words)
        self.round_words = list(self.preview_words)  # 记录错词轮起始词序
        self.wrong = []
        self.pos = 0
        self.phase = "normal"
        self.next_word()

    def restart(self):
        """重开当前这一轮：第 1 轮重开全部词，错词轮重开错词轮。
        全部完成时没有当前轮，则回到第 1 轮。"""
        self.judge_seq += 1
        self.preview.pack_forget()
        self.pos_label.pack(pady=(8, 0))
        self.meaning.pack(pady=4)
        self.masked.pack(pady=6)
        self.result_label.pack(pady=6)
        self.entry.pack(pady=8, ipady=4)
        self.btns.pack(pady=10)
        self.total = len(WORDS)  # 动态总数：新录入的词重开第 1 轮即生效
        if self.round == 1 or self.entry.cget("state") == "disabled":
            # 第 1 轮重开全部词；全部完成态重开也回到第 1 轮全部词
            self.round = 1
            self.round_words = list(range(self.total))
        self.queue = list(self.round_words)
        self.wrong = []
        self.pos = 0
        self.phase = "normal"
        self.entry.config(state="normal")
        self.entry.delete(0, tk.END)
        self.next_word()

    def next_word(self):
        if not self.queue:
            # 空词表：引导录入
            self.progress.config(text="词表为空")
            self.meaning.config(text="点「加词」录入新词")
            self.pos_label.config(text="")
            self.masked.config(text="")
            self.result_label.config(text="")
            self.entry.config(state="disabled")
            self.btn_submit.grid_remove()
            self.btn_dont.grid_remove()
            self.btn_next.grid_remove()
            return
        if self.phase == "wrong":
            # 答错后放弃：公布答案，答案挂屏幕上同时进入下一题，该词记入错词
            widx_prev = self.queue[self.pos - 1]
            if widx_prev not in self.wrong:
                self.wrong.append(widx_prev)
            w_prev, _, m_prev = WORDS[widx_prev]
            shown = ("释义：" + m_prev) if self.mode == "en2cn" else ("原词：" + w_prev)
            self.result_label.config(text=shown, fg="red")
        else:
            self.result_label.config(text="")
        if self.pos >= len(self.queue):
            # —— 本轮结束：有错词则开错词轮，全对则完成 ——
            if self.wrong:
                # 本轮结束：先列出错词让用户过一遍，再开始错词轮
                self.preview_words = list(self.wrong)
                self.show_preview()
                return
            else:
                self.progress.config(text="全部完成！")
                self.meaning.config(text="全部完成！共 %d 个词，默写 %d 轮" % (self.total, self.round))
                self.pos_label.config(text="")
                self.masked.config(text="")
                self.result_label.config(text="")
                self.entry.config(state="disabled")
                self.btn_submit.grid_remove()
                self.btn_dont.grid_remove()
                self.btn_next.grid_remove()
                return
        widx = self.queue[self.pos]
        self.pos += 1
        if self.round == 1:
            self.progress.config(text="第 %d / %d 词" % (self.pos, len(self.queue)))
        else:
            self.progress.config(text="第 %d / %d 词 · 第 %d 轮（错词）" % (self.pos, len(self.queue), self.round))
        self.render_word()
        self.entry.config(state="normal")
        self.entry.delete(0, tk.END)
        self.entry.focus_set()
        self.phase = "normal"
        self.btn_submit.grid()
        self.btn_dont.grid()
        self.btn_next.grid_remove()

    def start_judge(self, ans, meaning):
        """异步叫本地 JEV 判一次（不卡界面）"""
        self.phase = "judging"
        self.judge_seq += 1
        seq = self.judge_seq
        self.result_label.config(text="模型判断中…", fg="#ef6c00")
        self.entry.config(state="disabled")
        self.btn_submit.grid_remove()
        self.btn_dont.grid_remove()
        self.btn_next.grid_remove()

        def work():
            p, err = self.judge.judge(meaning, ans)
            self._judge_q.put((seq, p, err))     # Tk 非线程安全：只投队列，主线程取

        threading.Thread(target=work, daemon=True).start()

    def _poll_judge(self):
        """主线程定时取判分结果（Tkinter 不能跨线程调用的安全做法）"""
        try:
            while True:
                seq, p, err = self._judge_q.get_nowait()
                self.finish_judge(seq, p, err)
        except queue.Empty:
            pass
        try:
            self.root.after(120, self._poll_judge)
        except Exception:
            pass

    def finish_judge(self, seq, p, err):
        """判分结果回到界面（在主线程里执行）"""
        if seq != self.judge_seq:
            return
        self.entry.config(state="normal")
        self.entry.delete(0, tk.END)
        th = self.judge.threshold if self.judge else 0.7
        if err or p is None or p < th:
            tip = "答错了，再试一次" + ("（接近度 %.2f）" % p if p is not None else "")
            self.result_label.config(text=tip, fg="red")
            self.phase = "wrong"
            self.btn_submit.grid()
            self.btn_dont.grid_remove()
            self.btn_next.grid()
        else:
            self.result_label.config(text="答对了！模型判为接近（%.2f）" % p, fg="green")
            self.phase = "correct"
            self.btn_submit.grid_remove()
            self.btn_dont.grid_remove()
            self.btn_next.grid()
        self.entry.focus_set()

    def on_close(self):
        """关窗：顺手把判分用的 llama-server 关掉"""
        try:
            if self.judge is not None:
                self.judge.close()
        finally:
            self.root.destroy()

    def mode_text(self):
        """模式按钮上显示的当前状态"""
        if self.mode == "en2cn":
            return "模式：单词 → 释义（点我切换）"
        return "模式：释义 → 单词（点我切换）"

    def toggle_mode(self):
        """切换 释义→单词 / 单词→释义，当前词按新模式重新出一次"""
        self.mode = "en2cn" if self.mode == "cn2en" else "cn2en"
        self.btn_mode.config(text=self.mode_text())
        self.judge_seq += 1                       # 作废在飞的判分结果
        if self.mode == "en2cn" and self.judge is not None:
            self.judge.start_async()              # 预热本地 JEV 服务
        if not self.queue:
            return
        if self.entry.cget("state") == "disabled":
            self.restart()      # 全部完成态：切模式后直接开新一轮
            return
        self.phase = "normal"
        self.result_label.config(text="")
        self.entry.config(state="normal")
        self.entry.delete(0, tk.END)
        self.entry.focus_set()
        self.btn_submit.grid()
        self.btn_dont.grid()
        self.btn_next.grid_remove()
        self.render_word()

    def render_word(self):
        """按当前模式渲染当前词的题面：cn2en 显示释义，en2cn 显示单词"""
        word, pos_, meaning = WORDS[self.queue[self.pos - 1]]
        self.pos_label.config(text=pos_)
        if self.mode == "en2cn":
            self.meaning.config(text=word, font=(MONO_FONT, 26, "bold"), fg="#111")
            self.masked.config(text="")
            self.entry.config(font=(UI_FONT, 18))
        else:
            self.meaning.config(text=meaning, font=(UI_FONT, 20, "bold"), fg="#222")
            self.masked.config(text=masked_display(word))
            self.entry.config(font=(MONO_FONT, 18))

    def add_words(self):
        """打开录入窗口，把新词追加进词表（保存到 dictation_extra.json）"""
        AddWordsDialog(self.root)


class AddWordsDialog:
    """录入新词：每行「单词 词性 释义」（词性可多个），可批量粘贴。
    重复的词自动跳过，录入后保存到同目录 dictation_extra.json"""

    def __init__(self, master):
        self.dlg = tk.Toplevel(master)
        self.dlg.title("录入新词")
        self.dlg.geometry("560x440")
        self.dlg.configure(bg="white")
        tk.Label(self.dlg, bg="white", fg="#555", justify="left",
                 font=(UI_FONT, 10),
                 text="支持两种格式：\n"
                      "① 和你发词表一样：先全部英文单词（一行一个），\n"
                      "   再全部中文释义（一行一个），两段数量要一致\n"
                      "② 每行一条：单词 词性 释义，如 fossil n. 化石\n"
                      "重复的词自动跳过，录入后点\"重开\"即可开始默写新词"
                 ).pack(anchor="w", padx=12, pady=(10, 4))
        self.text = tk.Text(self.dlg, font=(MONO_FONT, 12), height=10,
                            relief="solid", bd=1)
        self.text.pack(fill=tk.BOTH, expand=True, padx=12, pady=4)
        btn_row = tk.Frame(self.dlg, bg="white")
        btn_row.pack(pady=8)
        tk.Button(btn_row, text="录入", command=self.save, width=10,
                  font=(UI_FONT, 12), bg="#c8e6c9").pack(side=tk.LEFT, padx=6)
        tk.Button(btn_row, text="清空全部词", command=self.clear_extra, width=12,
                  font=(UI_FONT, 12), bg="#ffcdd2").pack(side=tk.LEFT, padx=6)
        tk.Button(btn_row, text="关闭", command=self.dlg.destroy, width=10,
                  font=(UI_FONT, 12), bg="#e0e0e0").pack(side=tk.LEFT, padx=6)
        self.msg = tk.Label(self.dlg, bg="white", font=(UI_FONT, 11), fg="#2e7d32")
        self.msg.pack(pady=(0, 8))
        self.text.focus_set()

    def clear_extra(self):
        """清空全部词：删除 dictation_extra.json，词表恢复为空（带确认）"""
        global WORDS
        path = os.path.join(BASE_DIR, "dictation_extra.json")
        extra_count = len(WORDS)
        if extra_count <= 0 and not os.path.exists(path):
            self.msg.config(text="当前没有词可清空", fg="#c62828")
            return
        if not messagebox.askyesno("确认清空",
                                   "将删除全部 %d 个词，词表将恢复为空。确定？"
                                   % extra_count):
            return
        try:
            os.remove(path)
        except OSError:
            pass
        WORDS[:] = list(BASE_WORDS)
        self.msg.config(text="已清空全部词，当前词表为空" if not WORDS
                        else "已清空，剩余 %d 个内置词" % len(WORDS), fg="#2e7d32")

    def save(self):
        global WORDS
        lines = [ln.strip() for ln in self.text.get("1.0", tk.END).splitlines() if ln.strip()]
        if not lines:
            self.msg.config(text="先粘贴词表再点录入", fg="#c62828")
            return
        known = {w for w, _, _ in WORDS}
        new_items, skipped = [], []
        # 判断格式：是否出现纯英文行（无中文）→ 两段式（先全部英文、后全部中文）
        has_cjk = [bool(re.search(r"[\u4e00-\u9fff]", ln)) for ln in lines]
        if any(not c for c in has_cjk):
            first_cjk = has_cjk.index(True)
            if any(not c for c in has_cjk[first_cjk:]):
                skipped.append("格式混杂：英文行和中文行交错，请检查后重试")
            elif first_cjk != len(has_cjk) - first_cjk:
                skipped.append("英文 %d 个、中文 %d 行，数量不一致" %
                               (first_cjk, len(has_cjk) - first_cjk))
            else:
                # 两段式：前段是单词，后段是释义，按行一一对应
                for w, m in zip(lines[:first_cjk], lines[first_cjk:]):
                    pos, meaning = split_pos_meaning(m)
                    if not meaning:
                        skipped.append(w + "（释义为空）")
                        continue
                    if w in known:
                        skipped.append(w + "（重复）")
                        continue
                    known.add(w)
                    new_items.append((w, pos, meaning))
        else:
            # 单行式：每行「单词 词性 释义」
            for line in lines:
                parts = line.split(None, 1)
                if len(parts) < 2:
                    skipped.append(line)
                    continue
                word, rest = parts
                pos, meaning = split_pos_meaning(rest)
                if not meaning:
                    skipped.append(line)
                    continue
                if word in known:
                    skipped.append(word + "（重复）")
                    continue
                known.add(word)
                new_items.append((word, pos, meaning))
        if not new_items:
            if skipped:
                self.msg.config(text="未录入任何词：" + "；".join(skipped[:3]), fg="#c62828")
            else:
                self.msg.config(text="没有可录入的词：检查格式或是否与已有词重复", fg="#c62828")
            return
        # 追加到外部词表文件（保留原有内容）
        path = os.path.join(BASE_DIR, "dictation_extra.json")
        try:
            with open(path, encoding="utf-8") as f:
                existing = json.load(f)
            if not isinstance(existing, list):
                existing = []
        except (OSError, ValueError):
            existing = []
        existing.extend([list(x) for x in new_items])
        with open(path, "w", encoding="utf-8") as f:
            json.dump(existing, f, ensure_ascii=False, indent=2)
        # 更新内存词表，重开一轮即可默写
        WORDS.extend(new_items)
        tip = "已录入 %d 个词" % len(new_items)
        if skipped:
            tip += "，跳过 %d 行（重复或格式不对）" % len(skipped)
        tip += "，点\"重开\"即可默写新词"
        self.msg.config(text=tip, fg="#2e7d32")
        self.text.delete("1.0", tk.END)


if __name__ == "__main__":
    # 高 DPI 缩放感知，防止缩放后按钮被挤出窗口
    try:
        from ctypes import windll
        windll.shcore.SetProcessDpiAwareness(1)
    except Exception:
        pass
    root = tk.Tk()
    app = DictationApp(root)
    root.mainloop()
