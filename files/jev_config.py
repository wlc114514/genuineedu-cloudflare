"""Shared configuration for the local JEV backend.

The browser talks to llama.cpp on loopback only. Keeping paths and model
parameters here makes the launcher testable without starting the model.
"""
from dataclasses import dataclass
from pathlib import Path
import platform

MODEL_NAME = "Jev-Style-0.8B-Decision-v3-Q4_K_M.gguf"
HOST = "127.0.0.1"
PORT = 8001

@dataclass(frozen=True)
class JevConfig:
    base_dir: Path
    host: str = HOST
    port: int = PORT
    model_name: str = MODEL_NAME

    @property
    def model_path(self) -> Path:
        return self.base_dir / "jev" / self.model_name

    @property
    def server_path(self) -> Path:
        name = "llama-server.exe" if platform.system() == "Windows" else "llama-server"
        return self.base_dir / "jev" / "llama" / name

    def command(self):
        return [str(self.server_path), "-m", str(self.model_path), "--host", self.host,
                "--port", str(self.port), "-c", "2048", "-t", "8", "--no-webui"]
