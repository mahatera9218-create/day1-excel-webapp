"""썸네일: 첫 장면 그림 위에 제목을 큼직하게 얹는다."""

import textwrap
from pathlib import Path

from ..config import FONT_DIR
from ..render.util import run

FONT = FONT_DIR / "NotoSansKR.ttf"


def _esc(text: str) -> str:
    return text.replace("\\", "\\\\").replace(":", "\\:").replace("'", "’").replace("%", "\\%")


def run_stage(run_dir: Path, plan: dict, cfg: dict) -> Path:
    src = run_dir / "images" / "scene_01.png"
    out = run_dir / "thumbnail.jpg"
    text = plan.get("topic") or plan["title"]
    lines = textwrap.wrap(text, width=10)[:3]
    draws = []
    for idx, line in enumerate(lines):
        y = f"(h-{len(lines)}*130)/2+{idx}*130"
        draws.append(
            f"drawtext=fontfile='{FONT}':text='{_esc(line)}':fontcolor=white:fontsize=96:"
            f"borderw=8:bordercolor=black:x=(w-tw)/2:y={y}")
    vf = f"scale=1280:720:force_original_aspect_ratio=increase,crop=1280:720," + ",".join(draws)
    run(["-i", src, "-vf", vf, "-frames:v", "1", "-q:v", "3", out])
    return out
