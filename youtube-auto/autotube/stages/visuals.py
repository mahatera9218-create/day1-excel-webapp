"""그림: 장면마다 그림 1장. motion 이 video 인 장면은 그림을 움직이는 영상으로도 변환.

애셋 재활용으로 토큰·크레딧을 아낀다:
- scene["image_ref"]: 같은 편의 '이전 장면 번호' 그림을 그대로 재사용(생성 0회).
- scene["image_lib"]: 채널 공용 라이브러리(channels/<ch>/assets_library/<key>.*)를 재사용.
  (라이브러리에 없으면 image_prompt 로 생성하는 폴백.)
"""

import json
import shutil
from pathlib import Path

from ..engines import Engines
from ..render.util import probe_duration

_LIB_EXTS = (".png", ".jpg", ".jpeg", ".webp")


def library_file(cfg: dict, key: str) -> Path | None:
    """채널 공용 라이브러리에서 key 에 해당하는 이미지 파일을 찾는다."""
    base = cfg["_dir"] / "assets_library"
    for ext in _LIB_EXTS:
        p = base / f"{key}{ext}"
        if p.exists():
            return p
    return None


def run(run_dir: Path, plan: dict, cfg: dict) -> None:
    engines = Engines(cfg)
    style = cfg["visual_style"].strip()
    images = run_dir / "images"
    clips = run_dir / "clips"
    images.mkdir(exist_ok=True)
    clips.mkdir(exist_ok=True)
    timing = json.loads((run_dir / "timing.json").read_text(encoding="utf-8"))
    n = len(plan["scenes"])
    for i, scene in enumerate(plan["scenes"], 1):
        key = f"{i:02}"
        png = images / f"scene_{key}.png"
        if not png.exists():
            ref = scene.get("image_ref")
            lib = scene.get("image_lib")
            src = None
            if ref:  # 같은 편의 이전 장면 재사용
                cand = images / f"scene_{int(ref):02}.png"
                if cand.exists():
                    src = cand
            elif lib:  # 채널 공용 라이브러리 재사용
                src = library_file(cfg, str(lib))
            if src is not None:
                print(f"      장면 {i}/{n} 그림 재활용 ← {src.name}")
                shutil.copyfile(src, png)
            else:
                print(f"      장면 {i}/{n} 그림 생성")
                engines.image({**scene, "_label": f"#{i}", "_style": style}, png)
        if scene.get("motion") == "video":
            clip = clips / f"scene_{key}.mp4"
            if not clip.exists():
                dur = timing[key]["duration"]
                print(f"      장면 {i} 영상 변환 ({dur:.1f}초)")
                engines.video({**scene, "_label": f"#{i}", "_style": style}, png, clip, dur)
