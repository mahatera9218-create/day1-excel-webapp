"""키·비용 없이 전체 흐름을 시험하는 가짜 엔진.

- 목소리: 내레이션 길이만큼의 무음 트랙
- 그림: 장면 번호가 적힌 색 카드
- 영상: 움직이는 테스트 패턴
"""

import hashlib
from pathlib import Path

from ..config import FONT_DIR
from ..render.util import frame_size, run
from .base import estimate_seconds, even_timing

_FONT = FONT_DIR / "NotoSansKR.ttf"


class MockEngine:
    name = "mock"

    def __init__(self, cfg: dict):
        self.size = frame_size("long")

    def voice(self, scene: dict, out: Path) -> dict:
        dur = estimate_seconds(scene["narration"])
        run(["-f", "lavfi", "-i", "anullsrc=r=44100:cl=stereo", "-t", f"{dur:.3f}",
             "-c:a", "libmp3lame", "-b:a", "128k", out])
        return even_timing(scene, dur)

    def image(self, scene: dict, out: Path) -> None:
        w, h = self.size
        hue = int(hashlib.md5(scene["image_prompt"].encode()).hexdigest(), 16) % 360
        label = scene.get("_label", "scene")
        run(["-f", "lavfi", "-i", f"color=c=gray:s={w}x{h}",
             "-vf", (f"hue=h={hue},drawbox=x=0:y=0:w={w}:h={h}:t=20:color=white@0.3,"
                     f"drawtext=fontfile='{_FONT}':text='{label}':fontcolor=white:fontsize=120:x=(w-tw)/2:y=(h-th)/2"),
             "-frames:v", "1", out])

    def video(self, scene: dict, image: Path, out: Path, duration: float) -> None:
        w, h = self.size
        run(["-f", "lavfi", "-i", f"testsrc2=s={w}x{h}:rate=25:duration={duration:.3f}",
             "-vf", "format=yuv420p", "-c:v", "libx264", "-preset", "medium", "-crf", "22", out])
