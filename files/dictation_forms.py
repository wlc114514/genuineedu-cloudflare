# -*- coding: utf-8 -*-
"""变形默写 v2：一屏一个词条，原词+各变形各占一行
左侧提示（原词行=原释义，变形行=词性+语义标注），右侧蓝色框默写
答对自动跳下一行并显示释义；答错可再试，点"下一个"放弃则公布答案记入错题；错题轮重练至全对"""
import tkinter as tk

WORDS = [
    {
        "meaning": 'v. 施加；发挥',
        "forms": [
            ('exert', 'v.', '施加；发挥', ''),
            ('exertion', 'n.', '努力；施加', ''),
        ],
    },
    {
        "meaning": 'n. 表达；表现',
        "forms": [
            ('express', 'v.', '表达', ''),
            ('expression', 'n.', '表达', ''),
            ('expressive', 'adj.', '富有表现力的', ''),
        ],
    },
    {
        "meaning": 'n. 因素',
        "forms": [
            ('factor', 'n.', '因素', ''),
        ],
    },
    {
        "meaning": 'n. 设施；场所',
        "forms": [
            ('facility', 'n.', '设施', ''),
            ('facilities', 'n.', '设施（复数）', '复数'),
        ],
    },
    {
        "meaning": 'n./v. 特征；以……为特色',
        "forms": [
            ('feature', 'n./v.', '特征', ''),
        ],
    },
    {
        "meaning": 'v. 喂养；进食',
        "forms": [
            ('feed', 'v.', '喂养', ''),
            ('feeding', 'n.', '喂养；进食', ''),
        ],
    },
    {
        "meaning": 'n. 领域；田地',
        "forms": [
            ('field', 'n.', '领域', ''),
        ],
    },
    {
        "meaning": 'v. 繁荣；茂盛',
        "forms": [
            ('flourish', 'v.', '繁荣', ''),
            ('flourishing', 'adj.', '繁荣的', ''),
        ],
    },
    {
        "meaning": 'n./v. 洪水；淹没',
        "forms": [
            ('flood', 'n./v.', '洪水；淹没', ''),
            ('flooding', 'n.', '泛滥', ''),
        ],
    },
    {
        "meaning": 'n./v. 形式；形成',
        "forms": [
            ('form', 'n./v.', '形式；形成', ''),
            ('formation', 'n.', '形成；结构', ''),
            ('formal', 'adj.', '正式的', ''),
            ('formulate', 'v.', '制定；形成', '动作'),
        ],
    },
    {
        "meaning": 'n. 基础',
        "forms": [
            ('foundation', 'n.', '基础', ''),
            ('found', 'v.', '建立', '动作'),
            ('foundational', 'adj.', '基础的', ''),
        ],
    },
    {
        "meaning": 'v. 促进；培养',
        "forms": [
            ('foster', 'v.', '促进；培养', ''),
            ('fostering', 'adj.', '促进的', ''),
        ],
    },
    {
        "meaning": 'n. 频率',
        "forms": [
            ('frequency', 'n.', '频率', ''),
            ('frequent', 'adj.', '频繁的', ''),
            ('frequently', 'adv.', '经常地', ''),
        ],
    },
    {
        "meaning": 'n./v. 燃料；提供动力',
        "forms": [
            ('fuel', 'n./v.', '燃料；提供动力', ''),
            ('fueled/fuelled', 'adj.', '充满动力的', ''),
        ],
    },
    {
        "meaning": 'n./v. 功能；起作用',
        "forms": [
            ('function', 'n./v.', '功能；起作用', ''),
            ('functional', 'adj.', '功能性的', ''),
            ('functionally', 'adv.', '功能上地', ''),
        ],
    },
    {
        "meaning": 'adj. 基础的；根本的',
        "forms": [
            ('fundamental', 'adj.', '基础的', ''),
            ('fundamentally', 'adv.', '根本地', ''),
        ],
    },
    {
        "meaning": 'n. 星系',
        "forms": [
            ('galaxy', 'n.', '星系', ''),
            ('galactic', 'adj.', '星系的', ''),
        ],
    },
    {
        "meaning": 'adj. 普遍的；总体的',
        "forms": [
            ('general', 'adj.', '普遍的', ''),
            ('generally', 'adv.', '通常地', ''),
            ('generalize', 'v.', '概括', '动作'),
        ],
    },
    {
        "meaning": 'n. 类型；体裁',
        "forms": [
            ('genre', 'n.', '类型；体裁', ''),
        ],
    },
    {
        "meaning": 'adj. 地质的',
        "forms": [
            ('geology', 'n.', '地质学', ''),
            ('geological', 'adj.', '地质的', ''),
            ('geologist', 'n.', '地质学家', '职业'),
        ],
    },
    {
        "meaning": 'n. 地质学家',
        "forms": [
            ('geology', 'n.', '地质学', ''),
            ('geological', 'adj.', '地质的', ''),
            ('geologist', 'n.', '地质学家', '职业'),
        ],
    },
    {
        "meaning": 'n. 地球；球体',
        "forms": [
            ('globe', 'n.', '地球；球体', ''),
            ('global', 'adj.', '全球的', ''),
            ('globally', 'adv.', '全球地', ''),
        ],
    },
    {
        "meaning": 'v. 管理；统治',
        "forms": [
            ('govern', 'v.', '管理', ''),
            ('government', 'n.', '政府', '机构'),
            ('governor', 'n.', '管理者；州长', '职位'),
            ('governing', 'adj.', '管理的', ''),
        ],
    },
    {
        "meaning": 'n. 重力；严重性',
        "forms": [
            ('gravity', 'n.', '重力', ''),
            ('gravitational', 'adj.', '重力的', ''),
        ],
    },
    {
        "meaning": 'n. 温室',
        "forms": [
            ('greenhouse', 'n.', '温室', ''),
        ],
    },
    {
        "meaning": 'n. 栖息地；生活环境',
        "forms": [
            ('habitat', 'n.', '栖息地', ''),
        ],
    },
    {
        "meaning": 'n. 手；v. 递交',
        "forms": [
            ('hand', 'n./v.', '手；递交', ''),
            ('handful', 'n.', '少量', '引申'),
            ('handmade', 'adj.', '手工制作的', ''),
        ],
    },
    {
        "meaning": 'v./n. 加热；热量',
        "forms": [
            ('heat', 'n./v.', '热量；加热', ''),
            ('heated', 'adj.', '加热的', ''),
            ('heating', 'n.', '加热', ''),
        ],
    },
    {
        "meaning": 'v./n. 帮助',
        "forms": [
            ('help', 'v./n.', '帮助', ''),
            ('helpful', 'adj.', '有帮助的', ''),
            ('helpless', 'adj.', '无助的', '反义'),
        ],
    },
    {
        "meaning": 'v. 冬眠',
        "forms": [
            ('hibernate', 'v.', '冬眠', ''),
            ('hibernation', 'n.', '冬眠', ''),
        ],
    },
    {
        "meaning": 'n. 历史',
        "forms": [
            ('history', 'n.', '历史', ''),
            ('historical', 'adj.', '历史的', ''),
            ('historically', 'adv.', '历史上地', ''),
            ('historian', 'n.', '历史学家', '职业'),
        ],
    },
    {
        "meaning": 'n. 激素',
        "forms": [
            ('hormone', 'n.', '激素', ''),
            ('hormonal', 'adj.', '激素的', ''),
        ],
    },
    {
        "meaning": 'adj./n. 人类的；人',
        "forms": [
            ('human', 'adj./n.', '人类；人', ''),
            ('humanity', 'n.', '人类；人性', ''),
            ('humanize', 'v.', '使人性化', ''),
        ],
    },
    {
        "meaning": 'v. 捕猎；寻找',
        "forms": [
            ('hunt', 'v./n.', '捕猎；寻找', ''),
            ('hunter', 'n.', '猎人', '职业'),
            ('hunting', 'n.', '捕猎', ''),
        ],
    },
    {
        "meaning": 'n. 想法；概念',
        "forms": [
            ('idea', 'n.', '想法', ''),
            ('ideal', 'adj./n.', '理想的；理想', '引申'),
        ],
    },
    {
        "meaning": 'v. 识别；确定',
        "forms": [
            ('identify', 'v.', '识别', ''),
            ('identification', 'n.', '识别；确认', ''),
            ('identity', 'n.', '身份；特征', '引申'),
        ],
    },
    {
        "meaning": 'adj. 非法的',
        "forms": [
            ('illegal', 'adj.', '非法的', ''),
            ('illegally', 'adv.', '非法地', ''),
        ],
    },
    {
        "meaning": 'n. 疾病',
        "forms": [
            ('ill', 'adj.', '生病的', ''),
            ('illness', 'n.', '疾病', ''),
        ],
    },
    {
        "meaning": 'n./v. 影响；冲击',
        "forms": [
            ('impact', 'n./v.', '影响', ''),
        ],
    },
    {
        "meaning": 'v. 改善；提高',
        "forms": [
            ('improve', 'v.', '改善', ''),
            ('improvement', 'n.', '改善', ''),
            ('improved', 'adj.', '改善的', ''),
        ],
    },
    {
        "meaning": 'v. 包含',
        "forms": [
            ('include', 'v.', '包含', ''),
            ('including', 'prep.', '包括', ''),
            ('inclusive', 'adj.', '包含的', ''),
        ],
    },
    {
        "meaning": 'v./n. 增加',
        "forms": [
            ('increase', 'v./n.', '增加', ''),
            ('increasing', 'adj.', '增长的', ''),
            ('increasingly', 'adv.', '越来越多地', ''),
        ],
    },
    {
        "meaning": 'v. 表明；指出',
        "forms": [
            ('indicate', 'v.', '表明', ''),
            ('indication', 'n.', '表明；迹象', ''),
            ('indicative', 'adj.', '指示性的', ''),
        ],
    },
    {
        "meaning": 'adj. 归纳的',
        "forms": [
            ('induce', 'v.', '导致；诱导', ''),
            ('induction', 'n.', '归纳；引入', ''),
            ('inductive', 'adj.', '归纳的', ''),
        ],
    },
    {
        "meaning": 'n./adj. 个体；个人的',
        "forms": [
            ('individual', 'n./adj.', '个体；个人的', ''),
            ('individually', 'adv.', '单独地', ''),
        ],
    },
    {
        "meaning": 'n./v. 影响',
        "forms": [
            ('influence', 'n./v.', '影响', ''),
            ('influential', 'adj.', '有影响力的', ''),
        ],
    },
    {
        "meaning": 'n. 创新',
        "forms": [
            ('innovate', 'v.', '创新', ''),
            ('innovation', 'n.', '创新', ''),
            ('innovative', 'adj.', '创新的', ''),
        ],
    },
    {
        "meaning": 'v. 激励；启发',
        "forms": [
            ('inspire', 'v.', '激励', ''),
            ('inspiration', 'n.', '灵感', ''),
            ('inspiring', 'adj.', '鼓舞人心的', '现在分词'),
            ('inspired', 'adj.', '受到启发的', '过去分词'),
        ],
    },
    {
        "meaning": 'n. 机构；制度',
        "forms": [
            ('institution', 'n.', '机构', ''),
            ('institutional', 'adj.', '机构的', ''),
        ],
    },
    {
        "meaning": 'adj./n. 智力的；知识分子',
        "forms": [
            ('intellect', 'n.', '智力', ''),
            ('intellectual', 'adj.', '智力的', ''),
            ('intellectually', 'adv.', '智力上地', ''),
        ],
    },
    {
        "meaning": 'v. 互动',
        "forms": [
            ('interact', 'v.', '互动', ''),
            ('interaction', 'n.', '互动', ''),
            ('interactive', 'adj.', '互动的', ''),
        ],
    },
    {
        "meaning": 'n./v. 兴趣；使感兴趣',
        "forms": [
            ('interest', 'n./v.', '兴趣', ''),
            ('interested', 'adj.', '感兴趣的', '过去分词'),
            ('interesting', 'adj.', '有趣的', '现在分词'),
        ],
    },
    {
        "meaning": 'v. 调查；研究',
        "forms": [
            ('investigate', 'v.', '调查', ''),
            ('investigation', 'n.', '调查', ''),
            ('investigator', 'n.', '调查者', '职业'),
        ],
    },
    {
        "meaning": 'v. 包含；涉及',
        "forms": [
            ('involve', 'v.', '涉及', ''),
            ('involvement', 'n.', '参与', ''),
        ],
    },
    {
        "meaning": 'n. 拼图',
        "forms": [
            ('jigsaw', 'n.', '拼图', ''),
        ],
    },
    {
        "meaning": 'v. 保持；保存',
        "forms": [
            ('keep', 'v.', '保持', ''),
            ('kept', 'v.', '保持（过去式/过去分词）', '过去式/分词'),
        ],
    },
    {
        "meaning": 'n. 知识',
        "forms": [
            ('knowledge', 'n.', '知识', ''),
            ('knowledgeable', 'adj.', '知识丰富的', ''),
        ],
    },
    {
        "meaning": 'n./v. 陆地；降落',
        "forms": [
            ('land', 'n./v.', '陆地；降落', ''),
            ('landscape', 'n.', '景观', '景观'),
            ('landed', 'adj.', '着陆的', ''),
        ],
    },
    {
        "meaning": 'adj. 大的',
        "forms": [
            ('large', 'adj.', '大的', ''),
            ('larger', 'adj.', '更大的', '比较级'),
            ('largest', 'adj.', '最大的', '最高级'),
        ],
    },
    {
        "meaning": 'n. 层',
        "forms": [
            ('layer', 'n.', '层', ''),
        ],
    },
    {
        "meaning": 'v. 导致；引导',
        "forms": [
            ('lead', 'v.', '导致；引导', ''),
            ('leader', 'n.', '领导者', '职业'),
            ('leading', 'adj.', '主要的', ''),
        ],
    },
    {
        "meaning": 'v. 学习',
        "forms": [
            ('learn', 'v.', '学习', ''),
            ('learning', 'n.', '学习', ''),
            ('learner', 'n.', '学习者', '职业'),
        ],
    },
    {
        "meaning": 'n. 腿',
        "forms": [
            ('leg', 'n.', '腿', ''),
        ],
    },
    {
        "meaning": 'n./adj./v. 光；轻的；点燃',
        "forms": [
            ('light', 'n./adj./v.', '光；轻；点燃', ''),
            ('lighting', 'n.', '照明', ''),
            ('lighter', 'adj.', '更轻的', '比较级'),
        ],
    },
    {
        "meaning": 'prep./v. 像；喜欢',
        "forms": [
            ('like', 'prep./v.', '像；喜欢', ''),
            ('likely', 'adj.', '可能的', '引申'),
            ('likeness', 'n.', '相似', ''),
        ],
    },
    {
        "meaning": 'n. 读写能力',
        "forms": [
            ('literate', 'adj.', '有读写能力的', ''),
            ('literacy', 'n.', '读写能力', '读写能力'),
        ],
    },
    {
        "meaning": 'n. 文学',
        "forms": [
            ('literature', 'n.', '文学', ''),
            ('literary', 'adj.', '文学的', '文学的'),
        ],
    },
    {
        "meaning": 'v./adj. 生活；活的',
        "forms": [
            ('live', 'v./adj.', '生活；活的', ''),
            ('life', 'n.', '生命', ''),
            ('living', 'adj./n.', '活着的；生活', ''),
        ],
    },
    {
        "meaning": 'n. 损失；丧失',
        "forms": [
            ('lose', 'v.', '失去', ''),
            ('loss', 'n.', '损失', ''),
            ('lost', 'adj.', '失去的', ''),
        ],
    },
    {
        "meaning": 'adj./adv. 长的；长久地',
        "forms": [
            ('long', 'adj./adv.', '长的', ''),
            ('longer', 'adj.', '更长的', '比较级'),
            ('longest', 'adj.', '最长的', '最高级'),
        ],
    },
    {
        "meaning": 'adj. 逻辑的',
        "forms": [
            ('logic', 'n.', '逻辑', ''),
            ('logical', 'adj.', '逻辑的', ''),
            ('logically', 'adv.', '逻辑上地', ''),
        ],
    },
    {
        "meaning": 'v./n. 看；外观',
        "forms": [
            ('look', 'v./n.', '看；外观', ''),
        ],
    },
    {
        "meaning": 'v. 维持；保持',
        "forms": [
            ('maintain', 'v.', '维持', ''),
            ('maintenance', 'n.', '维护', ''),
            ('maintained', 'adj.', '保持的', ''),
        ],
    },
    {
        "meaning": 'adj./n. 雄性的；男性',
        "forms": [
            ('male', 'adj./n.', '男性', ''),
            ('female', 'adj./n.', '女性', '反义'),
        ],
    },
    {
        "meaning": 'adj./n. 海洋的；海洋生物',
        "forms": [
            ('marine', 'adj.', '海洋的', ''),
            ('maritime', 'adj.', '海上的', '海上的'),
        ],
    },
    {
        "meaning": 'v./n. 标记；标志',
        "forms": [
            ('mark', 'v./n.', '标记', ''),
            ('marked', 'adj.', '明显的', ''),
        ],
    },
    {
        "meaning": 'n./adj. 材料；物质的',
        "forms": [
            ('material', 'n./adj.', '材料；物质的', ''),
            ('materially', 'adv.', '实质上地', ''),
        ],
    },
    {
        "meaning": 'n. 记忆',
        "forms": [
            ('memory', 'n.', '记忆', ''),
            ('memorize', 'v.', '记住', ''),
            ('memorable', 'adj.', '难忘的', ''),
        ],
    },
    {
        "meaning": 'v. 融化',
        "forms": [
            ('melt', 'v.', '融化', ''),
            ('melting', 'n./adj.', '融化；熔化的', ''),
        ],
    },
    {
        "meaning": 'n. 方法',
        "forms": [
            ('method', 'n.', '方法', ''),
            ('methodological', 'adj.', '方法论的', ''),
        ],
    },
    {
        "meaning": 'n. 迁移；迁徙',
        "forms": [
            ('migrate', 'v.', '迁移', ''),
            ('migration', 'n.', '迁移', '名词化'),
            ('migrant', 'n.', '移民；迁徙者', '人'),
        ],
    },
    {
        "meaning": 'n. 千年',
        "forms": [
            ('millennium', 'n.', '千年', ''),
            ('millennia', 'n.', '千年（复数）', '复数'),
        ],
    },
    {
        "meaning": 'n./v. 思维；介意',
        "forms": [
            ('mind', 'n./v.', '思维；介意', ''),
            ('mental', 'adj.', '心理的', ''),
            ('mentally', 'adv.', '心理上地', ''),
        ],
    },
    {
        "meaning": 'n. 矿物',
        "forms": [
            ('mineral', 'n.', '矿物', ''),
        ],
    },
    {
        "meaning": 'n. 任务；使命',
        "forms": [
            ('mission', 'n.', '任务', ''),
        ],
    },
    {
        "meaning": 'n./v. 模型；模拟',
        "forms": [
            ('model', 'n./v.', '模型；模拟', ''),
            ('modeling', 'n.', '建模', ''),
        ],
    },
    {
        "meaning": 'adj. 现代的',
        "forms": [
            ('modern', 'adj.', '现代的', ''),
            ('modernize', 'v.', '现代化', ''),
            ('modernization', 'n.', '现代化', ''),
        ],
    },
    {
        "meaning": 'v./n. 移动；运动',
        "forms": [
            ('move', 'v./n.', '移动', ''),
            ('movement', 'n.', '运动', ''),
        ],
    },
    {
        "meaning": 'n. 山；山脉',
        "forms": [
            ('mountain', 'n.', '山', ''),
            ('mountainous', 'adj.', '多山的', ''),
        ],
    },
    {
        "meaning": 'adj./n. 道德的；道德',
        "forms": [
            ('moral', 'adj./n.', '道德', ''),
            ('morality', 'n.', '道德', ''),
            ('morally', 'adv.', '道德上地', ''),
        ],
    },
    {
        "meaning": 'n. 神话',
        "forms": [
            ('myth', 'n.', '神话', ''),
            ('mythology', 'n.', '神话体系', '神话体系'),
            ('mythological', 'adj.', '神话的', ''),
        ],
    },
    {
        "meaning": 'adj. 自然的',
        "forms": [
            ('nature', 'n.', '自然', ''),
            ('natural', 'adj.', '自然的', ''),
            ('naturally', 'adv.', '自然地', ''),
        ],
    },
    {
        "meaning": 'adj. 消极的；负面的',
        "forms": [
            ('negative', 'adj.', '消极的', ''),
            ('negatively', 'adv.', '消极地', ''),
        ],
    },
    {
        "meaning": 'v./n. 需要',
        "forms": [
            ('need', 'v./n.', '需要', ''),
        ],
    },
    {
        "meaning": 'n. 营养物；养分',
        "forms": [
            ('nutrient', 'n.', '营养物', ''),
            ('nutrition', 'n.', '营养', '营养学'),
            ('nutritional', 'adj.', '营养的', ''),
        ],
    },
    {
        "meaning": 'v. 观察；注意到',
        "forms": [
            ('observe', 'v.', '观察', ''),
            ('observation', 'n.', '观察', '名词化'),
            ('observer', 'n.', '观察者', '职业'),
        ],
    },
    {
        "meaning": 'v. 获得',
        "forms": [
            ('obtain', 'v.', '获得', ''),
            ('obtainable', 'adj.', '可获得的', ''),
        ],
    },
    {
        "meaning": 'n. 海洋',
        "forms": [
            ('ocean', 'n.', '海洋', ''),
            ('oceanic', 'adj.', '海洋的', ''),
        ],
    },
    {
        "meaning": 'n. 生物',
        "forms": [
            ('organism', 'n.', '生物', ''),
            ('organic', 'adj.', '有机的', '引申'),
        ],
    },
    {
        "meaning": 'n. 起源；来源',
        "forms": [
            ('origin', 'n.', '起源', ''),
            ('originate', 'v.', '起源', ''),
            ('original', 'adj.', '原始的；最初的', ''),
        ],
    },
    {
        "meaning": 'adj./adv. 总体的',
        "forms": [
            ('overall', 'adj./adv.', '总体的', ''),
        ],
    },
]


class DictationApp:
    def __init__(self, root):
        self.root = root
        root.title("变形默写")
        root.geometry("760x660")
        root.configure(bg="white")

        self.total_words = len(WORDS)
        self.total_forms = sum(len(e["forms"]) for e in WORDS)
        self.round = 1
        first_queue = [(wi, list(range(len(WORDS[wi]["forms"])))) for wi in range(self.total_words)]
        self.queue = list(first_queue)      # 当前轮词条列表：[(词条号, 形式号列表)]
        self.round_queue = list(first_queue)  # 本轮起始（重开时恢复用）
        self.pos = 0                        # 本轮进行到第几个词条
        self.wrong_forms = []               # 本轮错题 [(词条号, 形式号)] 按出错顺序
        self.rows = []                      # 当前词条的行：[wi, fi, word, entry, st_label, phase, lbl, form_def]
        self.cur_row = 0                    # 当前激活行
        self.done = False                   # 全部完成标志

        self.progress = tk.Label(root, text="", bg="white",
                                 font=("Microsoft YaHei", 12), fg="gray")
        self.progress.pack(pady=(14, 2))

        self.row_frame = tk.Frame(root, bg="white")
        self.row_frame.pack(fill=tk.BOTH, expand=True, padx=24, pady=6)

        self.status = tk.Label(root, text="", bg="white",
                               font=("Microsoft YaHei", 12), fg="gray", wraplength=680)
        self.status.pack(pady=(0, 4))

        self.btns = tk.Frame(root, bg="white")
        self.btns.pack(pady=8)
        self.btn_submit = tk.Button(self.btns, text="提交", command=self.submit,
                                    width=8, font=("Microsoft YaHei", 12), bg="#e3f2fd")
        self.btn_submit.grid(row=0, column=0, padx=6)
        self.btn_dont = tk.Button(self.btns, text="不知道", command=self.give_up,
                                  width=8, font=("Microsoft YaHei", 12), bg="#fff8e1")
        self.btn_dont.grid(row=0, column=1, padx=6)
        self.btn_next = tk.Button(self.btns, text="下一个", command=self.btn_next_action,
                                  width=8, font=("Microsoft YaHei", 12),
                                  bg="#c8e6c9", takefocus=False)
        self.btn_next.grid(row=0, column=1, padx=6)
        self.btn_next.grid_remove()
        self.btn_restart = tk.Button(self.btns, text="重开", command=self.restart,
                                     width=8, font=("Microsoft YaHei", 12), bg="#e8eaf6")
        self.btn_restart.grid(row=0, column=2, padx=6)

        # —— 错题预览页 ——
        self.preview = tk.Frame(root, bg="white")
        self.preview_title = tk.Label(self.preview, bg="white",
                                      font=("Microsoft YaHei", 14, "bold"), fg="#b71c1c")
        self.preview_title.pack(pady=(10, 4))
        self.preview_text = tk.Text(self.preview, font=("Microsoft YaHei", 11),
                                    width=64, height=12, relief="solid", bd=1)
        sb = tk.Scrollbar(self.preview, command=self.preview_text.yview)
        self.preview_text.configure(yscrollcommand=sb.set)
        sb.pack(side=tk.RIGHT, fill=tk.Y)
        self.preview_text.pack(fill=tk.BOTH, expand=True, padx=10)
        self.btn_row = tk.Frame(self.preview, bg="white")
        self.btn_start_round = tk.Button(self.btn_row, text="开始默写", command=self.start_round,
                                         width=12, font=("Microsoft YaHei", 12), bg="#c8e6c9")
        self.btn_start_round.pack(side=tk.LEFT, padx=6)
        self.btn_restart_pv = tk.Button(self.btn_row, text="重新开始", command=self.restart,
                                        width=12, font=("Microsoft YaHei", 12), bg="#e8eaf6")
        self.btn_restart_pv.pack(side=tk.LEFT, padx=6)
        self.btn_row.pack(pady=(4, 12))
        self.preview.pack_forget()

        self.next_word()

    # ---------- 一屏显示一个词条 ----------
    def show_word(self, wi, fis):
        for w in self.row_frame.winfo_children():
            w.destroy()
        self.rows = []
        meaning = WORDS[wi]["meaning"]
        forms = WORDS[wi]["forms"]
        if self.round > 1 and 0 not in fis:
            # 错题轮且原词没错：顶部显示原词作提示（不参与默写）
            tip = tk.Frame(self.row_frame, bg="#f5f5f5")
            tip.pack(fill=tk.X, pady=(0, 8))
            tip_text = "原词：%s　%s" % (forms[0][0], meaning)
            tk.Label(tip, text=tip_text, bg="#f5f5f5", fg="#666",
                     font=("Microsoft YaHei", 13), anchor="w").pack(fill=tk.X, padx=8, pady=4)
        for fi in fis:
            word, pos, form_def, extra = forms[fi]
            if fi == 0:
                hint = meaning
            else:
                hint = pos + (("（" + extra + "）") if extra else "")
                if self.round > 1:
                    hint = meaning + " → " + hint   # 错题轮补上原释义作上下文
            frame = tk.Frame(self.row_frame, bg="white")
            frame.pack(fill=tk.X, pady=5)
            frame.grid_columnconfigure(1, weight=1)   # 第 1 列（输入框）占满剩余空间
            lbl = tk.Label(frame, text=hint, bg="white", font=("Microsoft YaHei", 14),
                           fg="#222", anchor="w")
            lbl.grid(row=0, column=0, sticky="w", padx=(0, 10))
            entry = tk.Entry(frame, font=("Consolas", 15), justify="center",
                             highlightbackground="#1f6f8b", highlightthickness=2,
                             highlightcolor="#0d4d63", bg="#eaf4f7")
            entry.grid(row=0, column=1, sticky="ew", ipady=3)
            st = tk.Label(frame, text="", bg="white", font=("Microsoft YaHei", 12, "bold"),
                          fg="green", width=24, anchor="w", justify="left")
            st.grid(row=0, column=2, sticky="w", padx=(8, 0))
            self.rows.append([wi, fi, word, entry, st, "normal", lbl, form_def])
            entry.bind("<Return>", self.submit)
        self.cur_row = 0
        if self.rows:
            self.rows[0][3].focus_set()

    # ---------- 交互 ----------
    def submit(self, event=None):
        """提交当前行：判对错。答对自动跳下一行，答错可再试。
        本词条全部行完成后按 Enter = 点"下一个"按钮"""
        if self.cur_row >= len(self.rows):
            self.btn_next_action()
            return
        r = self.rows[self.cur_row]
        if r[5] == "correct":
            return
        word, entry, st = r[2], r[3], r[4]
        ans = entry.get().strip().lower()
        # 支持双拼写词形（如 burned/burnt）：写任意一个都算对
        if any(ans == w.lower() for w in word.split('/')):
            st.config(text="✓\n" + r[7], fg="green")   # 答对后显示该形式释义
            entry.config(bg="#e8f5e9", state="disabled")
            r[5] = "correct"
            self.btn_next.grid_remove()
            self.advance_row()
        else:
            st.config(text="答错了，再试一次", fg="red")
            r[5] = "wrong"
            self.btn_next.grid()
            self.btn_dont.grid_remove()
            entry.focus_set()

    def give_up(self):
        """不知道 / 答错放弃：公布答案、记入错题、跳下一行"""
        if self.cur_row >= len(self.rows):
            return
        r = self.rows[self.cur_row]
        if r[5] == "correct":
            return
        wi, fi, word, entry, st = r[0], r[1], r[2], r[3], r[4]
        self.wrong_forms.append((wi, fi))
        st.config(text="原词：" + word + "\n" + r[7], fg="red")   # 放弃后显示答案+该形式释义
        entry.delete(0, tk.END)
        entry.insert(0, word)
        entry.config(bg="#ffebee", state="disabled")
        r[5] = "revealed"
        self.advance_row()

    def btn_next_action(self):
        """答错时点=放弃当前行；词条完成时点=进入下一词条"""
        if self.cur_row < len(self.rows) and self.rows[self.cur_row][5] == "wrong":
            self.give_up()
        else:
            self.next_word()

    def advance_row(self):
        """答对/放弃后跳下一行；本词条全部行处理完则显示"下一个"按钮等用户点击"""
        self.btn_dont.grid()
        self.cur_row += 1
        if self.cur_row < len(self.rows):
            self.btn_next.grid_remove()
            nxt = self.rows[self.cur_row][3]
            nxt.config(state="normal")
            nxt.delete(0, tk.END)
            nxt.focus_set()
        else:
            # 本词条全部行完成：不自动跳转，等用户点"下一个"
            self.status.config(text="本词完成，点「下一个」继续")
            self.btn_next.grid()

    def next_word(self):
        if self.done:
            return
        if self.pos >= len(self.queue):
            # —— 本轮结束：有错题则开错题轮，全对则完成 ——
            if self.wrong_forms:
                self.preview_words = list(self.wrong_forms)
                self.show_preview()
            else:
                self.finish_all()
            return
        wi, fis = self.queue[self.pos]
        self.pos += 1
        if self.round == 1:
            self.progress.config(text="第 %d / %d 词" % (self.pos, len(self.queue)))
        else:
            self.progress.config(text="第 %d / %d 词 · 第 %d 轮（错词）" % (self.pos, len(self.queue), self.round))
        self.status.config(text="")
        self.show_word(wi, fis)
        self.btn_submit.grid()
        self.btn_dont.grid()
        self.btn_next.grid_remove()

    # ---------- 错题预览 / 错题轮 / 完成 / 重开 ----------
    def show_preview(self):
        for w in (self.row_frame, self.progress, self.status, self.btns):
            w.pack_forget()
        self.preview_text.config(state="normal")
        self.preview_text.delete("1.0", tk.END)
        for wi, fi in self.preview_words:
            word, pos, form_def, extra = WORDS[wi]["forms"][fi]
            self.preview_text.insert(tk.END, "%s  [%s]  %s\n" % (word, pos, form_def))
        self.preview_text.config(state="disabled")
        self.preview_title.config(text="本轮错题 %d 个，过一遍再开始" % len(self.preview_words))
        self.preview.pack(fill=tk.BOTH, expand=True, padx=16, pady=8)

    def start_round(self):
        """看完错题列表，开始错题轮（同词条的错题合并成一行一题）"""
        self.preview.pack_forget()
        self.row_frame.pack(fill=tk.BOTH, expand=True, padx=24, pady=6)
        self.progress.pack(pady=(14, 2))
        self.status.pack(pady=(0, 4))
        self.btns.pack(pady=8)
        self.round += 1
        groups, order = {}, []
        for wi, fi in self.wrong_forms:
            if wi not in groups:
                groups[wi] = []
                order.append(wi)
            if fi not in groups[wi]:
                groups[wi].append(fi)
        self.queue = [(wi, groups[wi]) for wi in order]
        self.round_queue = list(self.queue)
        self.wrong_forms = []
        self.pos = 0
        self.next_word()

    def finish_all(self):
        self.done = True
        self.progress.config(text="全部完成！")
        self.status.config(text="全部完成！共 %d 个词、%d 个形式，默写 %d 轮"
                                % (self.total_words, self.total_forms, self.round))
        for w in self.row_frame.winfo_children():
            w.destroy()
        self.rows = []
        self.cur_row = 0
        self.btn_submit.grid_remove()
        self.btn_dont.grid_remove()
        self.btn_next.grid_remove()

    def restart(self):
        """重开当前轮；全部完成态则回到第 1 轮"""
        self.done = False
        self.preview.pack_forget()
        self.row_frame.pack(fill=tk.BOTH, expand=True, padx=24, pady=6)
        self.progress.pack(pady=(14, 2))
        self.status.pack(pady=(0, 4))
        self.btns.pack(pady=8)
        if self.pos >= len(self.queue) and not self.rows:
            self.round = 1
            first_queue = [(wi, list(range(len(WORDS[wi]["forms"])))) for wi in range(self.total_words)]
            self.round_queue = list(first_queue)
        self.queue = list(self.round_queue)
        self.wrong_forms = []
        self.pos = 0
        self.next_word()


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
