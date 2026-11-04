"""쇼츠: 하이라이트 장면 몇 개를 세로(9:16)로 재편집해 유입용 쇼츠를 만든다.

롱폼에서 이미 만든 그림·음성을 재사용하므로 추가 비용이 거의 없다.
"""

import json
from pathlib import Path

from ..config import FONT_DIR
from ..render.kenburns import FPS
from ..render.subtitles import build_ass
from ..render.util import probe_duration, run


def _pick(plan: dict, n: int) -> list[int]:
    videos = [i for i, s in enumerate(plan["scenes"], 1) if s.get("motion") == "video"]
    rest = [i for i, _ in enumerate(plan["scenes"], 1) if i not in videos]
    return (videos + rest)[:n]


def run_stage(run_dir: Path, plan: dict, cfg: dict) -> list[Path]:
    sh = cfg.get("shorts", {})
    if not sh.get("enabled", True):
        return []
    size = (1080, 1920)
    w, h = size
    timing = json.loads((run_dir / "timing.json").read_text(encoding="utf-8"))
    out_dir = run_dir / "shorts"
    out_dir.mkdir(exist_ok=True)
    made = []
    sub_cfg = {**cfg["subtitles"], "font_size": 64, "margin_v": 320}
    for n, i in enumerate(_pick(plan, sh.get("count", 3)), 1):
        key = f"{i:02}"
        audio = run_dir / "audio" / f"scene_{key}.mp3"
        dur = min(probe_duration(audio), sh.get("max_seconds", 55))
        ass = out_dir / f"short_{n:02}.ass"
        chunks = [{"text": c["text"], "start": c["start"], "end": c["end"],
                   "highlight": c.get("highlight", [])} for c in timing[key]["chunks"] if c["start"] < dur]
        build_ass(chunks, sub_cfg, size, ass)
        frames = max(int(dur * FPS), 1)
        vf = (f"scale={w*2}:{h*2}:force_original_aspect_ratio=increase,crop={w*2}:{h*2},"
              f"zoompan=z='min(zoom+0.0012,1.2)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':"
              f"d={frames}:s={w}x{h}:fps={FPS},format=yuv420p,"
              f"subtitles={ass.name}:fontsdir={FONT_DIR}")
        out = out_dir / f"short_{n:02}.mp4"
        run(["-loop", "1", "-i", run_dir / "images" / f"scene_{key}.png", "-i", audio,
             "-t", f"{dur:.3f}", "-vf", vf, "-map", "0:v", "-map", "1:a",
             "-c:v", "libx264", "-preset", "medium", "-crf", "20", "-c:a", "aac",
             "-b:a", "192k", "-shortest", out.name], cwd=out_dir)
        made.append(out)
    return made
