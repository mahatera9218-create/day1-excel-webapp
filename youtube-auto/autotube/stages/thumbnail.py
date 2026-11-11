"""썸네일: '가장 자극적인 전용 이미지'를 꽉 채우고, 훅 한 줄을 '하단에' 크게 얹는다.

- plan 에 thumbnail_prompt 가 있으면 그걸로 전용 썸네일 이미지를 새로 생성.
- 없으면 thumbnail_scene(기본 1) 장면 그림을 사용.
- thumbnail_text 가 있으면 '하단 가운데'에 크게. 글자는 폭에 맞춰 자동 축소(안 잘림),
  밑에 가독성 그라데이션(스크림)을 깔아 어떤 배경에서도 읽히게 한다.
  (예전엔 '상단 고정'이라 전신/상반신 인물의 머리와 겹치고, 긴 글자는 좌우가 잘렸다.)
"""

import textwrap
from pathlib import Path

from ..config import FONT_DIR
from ..engines import Engines
from ..render.util import ffpath, run

FONT = FONT_DIR / "NotoSansKR.ttf"
BRAND = FONT_DIR.parent / "brand" / "brand_overlay.png"   # Mr.Untold 워드마크(1280x720 투명)
SCRIM = FONT_DIR.parent / "brand" / "scrim_bottom.png"    # 하단 가독성 그라데이션(1280x720 투명)


def _esc(text: str) -> str:
    return text.replace("\\", "\\\\").replace(":", "\\:").replace("'", "’").replace("%", "\\%")


def _fit_fontsize(line: str) -> int:
    """Pillow 없이 '좌우로 안 잘리는' 글자 크기를 보수적으로 추정한다(대문자 볼드 기준).
    폭 ~1100px 안에 들어오게. 짧으면 크게(최대 112), 길면 작게(최소 56)."""
    n = max(1, len(line))
    return max(56, min(112, int(1100 / (n * 0.62))))


def run_stage(run_dir: Path, plan: dict, cfg: dict) -> Path:
    out = run_dir / "thumbnail.jpg"
    # 1) 썸네일용 원본 이미지 확보
    tprompt = (plan.get("thumbnail_prompt") or "").strip()
    if tprompt:
        src = run_dir / "images" / "thumb_src.png"
        if not src.exists():
            style = cfg["visual_style"].strip()
            Engines(cfg).image({"image_prompt": tprompt, "_style": style, "_label": "T"}, src)
    else:
        idx = int(plan.get("thumbnail_scene", 1))
        src = run_dir / "images" / f"scene_{idx:02}.png"
        if not src.exists():
            src = run_dir / "images" / "scene_01.png"

    # 2) 꽉 채우기 + 영화 같은 보정(대비/채도/샤픈)
    grade = ("scale=1280:720:force_original_aspect_ratio=increase,crop=1280:720,"
             "eq=contrast=1.14:saturation=1.3:brightness=0.03,unsharp=5:5:0.9:5:5:0.0")

    caption = (plan.get("thumbnail_text") or "").strip()
    line = _esc(textwrap.shorten(caption.upper(), width=28, placeholder="")) if caption else ""

    # 3) 입력(원본 + 하단 스크림 + 브랜드)을 모아 필터체인을 구성한다.
    inputs = ["-i", str(src)]
    nxt = 1
    scrim_i = brand_i = None
    if line and SCRIM.exists():
        inputs += ["-i", str(SCRIM)]; scrim_i = nxt; nxt += 1
    if BRAND.exists():
        inputs += ["-i", str(BRAND)]; brand_i = nxt; nxt += 1

    parts = [f"[0:v]{grade}[v0]"]
    cur = "[v0]"
    if scrim_i is not None:                       # 글자 밑에 깔 그라데이션(가독성)
        parts.append(f"{cur}[{scrim_i}:v]overlay=0:0[v1]"); cur = "[v1]"
    if line:                                       # 훅 한 줄: 하단 가운데, 자동 크기, 두꺼운 외곽선+그림자
        fs = _fit_fontsize(line)
        parts.append(
            f"{cur}drawtext=fontfile={ffpath(FONT)}:text='{line}':fontcolor=white:fontsize={fs}:"
            f"borderw=8:bordercolor=black:shadowx=4:shadowy=4:shadowcolor=black@0.8:"
            f"x=(w-tw)/2:y=h-th-80[v2]")
        cur = "[v2]"
    if brand_i is not None:                        # Mr.Untold 워드마크(항상)
        parts.append(f"{cur}[{brand_i}:v]overlay=0:0[v3]"); cur = "[v3]"

    if len(parts) == 1:                            # 보정만 (글자·오버레이 없음)
        run(["-i", str(src), "-vf", grade, "-frames:v", "1", "-q:v", "2", out])
    else:
        run([*inputs, "-filter_complex", ";".join(parts), "-map", cur,
             "-frames:v", "1", "-q:v", "2", out])
    return out
