"""썸네일: '가장 자극적인 전용 이미지'를 꽉 채우고 영화 같은 보정만. (글자 도배 X)

- plan 에 thumbnail_prompt 가 있으면 그걸로 전용 썸네일 이미지를 새로 생성.
- 없으면 thumbnail_scene(기본 1) 장면 그림을 사용.
- thumbnail_text 가 있으면 위쪽에 '크고 굵게' 훅 한 줄(2~4단어)을 얹는다. 없으면 글자 없음.
"""

import textwrap
from pathlib import Path

from ..config import FONT_DIR
from ..engines import Engines
from ..render.util import run

FONT = FONT_DIR / "NotoSansKR.ttf"
BRAND = FONT_DIR.parent / "brand" / "brand_overlay.png"  # Mr.Untold 워드마크(1280x720 투명)


def _esc(text: str) -> str:
    return text.replace("\\", "\\\\").replace(":", "\\:").replace("'", "’").replace("%", "\\%")


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

    # 2) 꽉 채우기 + 영화 같은 보정(대비/채도/비네트)
    vf = ("scale=1280:720:force_original_aspect_ratio=increase,crop=1280:720,"
          "eq=contrast=1.1:saturation=1.22:brightness=-0.02,"
          "vignette=PI/5")

    # 3) (선택) 작은 캡션 — 있으면 '위쪽'에 (아래는 브랜드 워드마크 자리)
    caption = (plan.get("thumbnail_text") or "").strip()
    if caption:
        line = _esc(textwrap.shorten(caption.upper(), width=20, placeholder=""))
        # 큰 훅 한 줄: 화면 위쪽 가운데, 두꺼운 외곽선+그림자 (피사체 얼굴은 보통 중앙이라 상단 배치)
        vf += (f",drawtext=fontfile='{FONT}':text='{line}':fontcolor=white:fontsize=104:"
               f"borderw=9:bordercolor=black:shadowx=4:shadowy=4:shadowcolor=black@0.8:"
               f"x=(w-tw)/2:y=58")

    # 4) Mr.Untold 브랜드 워드마크를 항상 얹는다
    if BRAND.exists():
        run(["-i", src, "-i", str(BRAND), "-filter_complex",
             f"[0:v]{vf}[b];[b][1:v]overlay=0:0", "-frames:v", "1", "-q:v", "2", out])
    else:
        run(["-i", src, "-vf", vf, "-frames:v", "1", "-q:v", "2", out])
    return out
