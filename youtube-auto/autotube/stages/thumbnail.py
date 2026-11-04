"""썸네일: 장면 그림 위에 '짧고 강렬한 후킹 문구'를 유튜브식으로 크게 얹는다."""

import textwrap
from pathlib import Path

from ..config import FONT_DIR
from ..render.util import run

FONT = FONT_DIR / "NotoSansKR.ttf"


def _esc(text: str) -> str:
    return text.replace("\\", "\\\\").replace(":", "\\:").replace("'", "’").replace("%", "\\%")


def _hook_text(plan: dict) -> str:
    # 대본의 thumbnail_text 를 우선 사용, 없으면 제목/주제에서 짧게.
    txt = (plan.get("thumbnail_text") or "").strip()
    if not txt:
        txt = (plan.get("title") or plan.get("topic") or "").split("|")[0].strip()
    return txt.upper()


def run_stage(run_dir: Path, plan: dict, cfg: dict) -> Path:
    idx = int(plan.get("thumbnail_scene", 1))
    src = run_dir / "images" / f"scene_{idx:02}.png"
    if not src.exists():
        src = run_dir / "images" / "scene_01.png"
    out = run_dir / "thumbnail.jpg"

    text = _hook_text(plan)
    lines = textwrap.wrap(text, width=13)[:3] or [text]
    n = len(lines)
    size = 150 if n == 1 else (120 if n == 2 else 96)
    gap = size + 24
    draws = []
    for i, line in enumerate(lines):
        # 가운데 정렬, 세로로 쌓기. 굵은 검은 테두리 + 그림자 + 노란 글자.
        y = f"(h-{n}*{gap})/2 + {i}*{gap} + 40"
        draws.append(
            f"drawtext=fontfile='{FONT}':text='{_esc(line)}':fontcolor=#FFD400:fontsize={size}:"
            f"borderw=12:bordercolor=black:shadowx=6:shadowy=6:shadowcolor=black@0.6:"
            f"x=(w-tw)/2:y={y}")
    # 그림을 약간 어둡게 + 아래쪽을 더 어둡게 깔아 글자가 확 튀게.
    vf = ("scale=1280:720:force_original_aspect_ratio=increase,crop=1280:720,"
          "eq=brightness=-0.06:saturation=1.15,"
          "drawbox=x=0:y=0:w=1280:h=720:color=black@0.28:t=fill,"
          + ",".join(draws))
    run(["-i", src, "-vf", vf, "-frames:v", "1", "-q:v", "3", out])
    return out
