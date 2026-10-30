"""설정 파일(config.yaml)과 비밀 키(.env)를 읽는다."""

import os
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent


def load_env(path: Path = ROOT / ".env") -> None:
    """.env 의 KEY=VALUE 를 환경 변수로 올린다. 이미 설정된 값은 덮어쓰지 않는다."""
    if not path.exists():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


def load_config(path: Path | None = None) -> dict:
    path = path or ROOT / "config.yaml"
    if not path.exists():
        path = ROOT / "config.example.yaml"
        print(f"[알림] config.yaml 이 없어 {path.name} 설정으로 실행합니다.")
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def require_env(name: str) -> str:
    value = os.environ.get(name, "")
    if not value or value.endswith("..."):
        raise SystemExit(f"[오류] {name} 이(가) 비어 있습니다. .env 파일에 키를 넣어주세요.")
    return value
