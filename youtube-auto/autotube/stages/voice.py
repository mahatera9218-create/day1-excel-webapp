"""목소리: 장면마다 내레이션 음성 + 자막 타이밍을 만든다. (음성 길이가 장면 길이를 정함)"""

import json
from pathlib import Path

from ..engines import Engines


def run(run_dir: Path, plan: dict, cfg: dict) -> None:
    engines = Engines(cfg)
    audio = run_dir / "audio"
    audio.mkdir(exist_ok=True)
    timing = {}
    timing_path = run_dir / "timing.json"
    if timing_path.exists():
        timing = json.loads(timing_path.read_text(encoding="utf-8"))
    for i, scene in enumerate(plan["scenes"], 1):
        key = f"{i:02}"
        mp3 = audio / f"scene_{key}.mp3"
        if mp3.exists() and key in timing:
            continue
        print(f"      장면 {i}/{len(plan['scenes'])} 음성")
        timing[key] = engines.voice(scene, mp3)
        timing_path.write_text(json.dumps(timing, ensure_ascii=False, indent=2), encoding="utf-8")
