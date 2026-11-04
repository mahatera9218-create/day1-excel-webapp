"""그림: 장면마다 그림 1장. motion 이 video 인 장면은 그림을 움직이는 영상으로도 변환."""

import json
from pathlib import Path

from ..engines import Engines
from ..render.util import probe_duration


def run(run_dir: Path, plan: dict, cfg: dict) -> None:
    engines = Engines(cfg)
    style = cfg["visual_style"].strip()
    images = run_dir / "images"
    clips = run_dir / "clips"
    images.mkdir(exist_ok=True)
    clips.mkdir(exist_ok=True)
    timing = json.loads((run_dir / "timing.json").read_text(encoding="utf-8"))
    for i, scene in enumerate(plan["scenes"], 1):
        key = f"{i:02}"
        scene = {**scene, "_label": f"#{i}", "_style": style}
        png = images / f"scene_{key}.png"
        if not png.exists():
            print(f"      장면 {i}/{len(plan['scenes'])} 그림")
            engines.image(scene, png)
        if scene.get("motion") == "video":
            clip = clips / f"scene_{key}.mp4"
            if not clip.exists():
                dur = timing[key]["duration"]
                print(f"      장면 {i} 영상 변환 ({dur:.1f}초)")
                engines.video(scene, png, clip, dur)
