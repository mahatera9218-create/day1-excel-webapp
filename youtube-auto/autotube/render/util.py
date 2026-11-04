"""ffmpeg 공용 도우미."""

import json
import subprocess
from pathlib import Path


def run(args: list, cwd: Path | None = None) -> None:
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", *map(str, args)], check=True, cwd=cwd)


def probe_duration(path: Path) -> float:
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "json", str(path)],
        check=True, capture_output=True, text=True,
    ).stdout
    return float(json.loads(out)["format"]["duration"])


def frame_size(fmt: str) -> tuple[int, int]:
    return (1080, 1920) if fmt == "shorts" else (1920, 1080)
