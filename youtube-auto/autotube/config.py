"""채널 설정(channel.yaml)과 비밀 키(.env)를 읽는다."""

import os
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
CHANNELS = ROOT / "channels"
# 기획안(plan.json)·검토본(script.md)·타이밍은 여기 저장되어 GitHub 에 커밋된다.
# 무거운 미디어(mp4/mp3/png)는 .gitignore 로 제외하고, GitHub 실행 시 새로 생성한다.
OUTPUT = ROOT / "episodes"
FONT_DIR = Path(__file__).resolve().parent / "assets" / "fonts"


def load_env(path: Path = ROOT / ".env") -> None:
    if not path.exists():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


def load_channel(name: str) -> dict:
    path = CHANNELS / name / "channel.yaml"
    if not path.exists():
        raise SystemExit(f"[오류] 채널 설정이 없습니다: {path}")
    cfg = yaml.safe_load(path.read_text(encoding="utf-8"))
    cfg["_name"] = name
    cfg["_dir"] = CHANNELS / name
    return cfg


def require_env(name: str) -> str:
    value = os.environ.get(name, "")
    if not value:
        raise SystemExit(f"[오류] {name} 이(가) 비어 있습니다. .env 또는 GitHub Secrets 에 넣어주세요.")
    return value
