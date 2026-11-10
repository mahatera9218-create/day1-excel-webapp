"""ffmpeg 공용 도우미."""

import json
import subprocess
from pathlib import Path


def run(args: list, cwd: Path | None = None) -> None:
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", *map(str, args)], check=True, cwd=cwd)


def ffpath(p) -> str:
    """ffmpeg 필터 문자열(drawtext fontfile, subtitles fontsdir 등) 안에 넣을 경로를
    안전하게 바꾼다. 윈도우의 'C:\\...' 는 ':'·'\\' 가 필터 특수문자라 깨지므로
    역슬래시→'/' , ':'→'\\:' 로 이스케이프. 리눅스 경로(콜론·역슬래시 없음)는 그대로."""
    return str(p).replace("\\", "/").replace(":", "\\:")


def probe_duration(path: Path) -> float:
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "json", str(path)],
        check=True, capture_output=True, text=True,
    ).stdout
    return float(json.loads(out)["format"]["duration"])


def frame_size(fmt: str) -> tuple[int, int]:
    return (1080, 1920) if fmt == "shorts" else (1920, 1080)
