"""합성: 장면별 클립(그림+움직임+내레이션) → 이어붙이기 → 강조 자막 → 배경음악 → final.mp4"""

import json
from pathlib import Path

from ..config import FONT_DIR
from ..render.kenburns import FPS
from ..render.subtitles import build_ass
from ..render.util import frame_size, probe_duration, run


def _scene_clip(scene: dict, image: Path, clip: Path | None, audio: Path, dur: float,
                size: tuple[int, int], out: Path) -> None:
    w, h = size
    if clip and clip.exists():
        vf = (f"scale={w}:{h}:force_original_aspect_ratio=decrease,"
              f"pad={w}:{h}:(ow-iw)/2:(oh-ih)/2,fps={FPS},format=yuv420p")
        src = ["-stream_loop", "-1", "-i", clip]
    else:
        frames = max(int(dur * FPS), 1)
        motion = scene.get("motion", "kenburns_in")
        base = f"scale={w*2}:{h*2}:force_original_aspect_ratio=increase,crop={w*2}:{h*2}"
        if motion == "kenburns_pan":
            z, x, y = "min(zoom+0.0008,1.15)", f"(iw-iw/zoom)*on/{frames}", "ih/2-(ih/zoom/2)"
        else:
            z, x, y = "min(zoom+0.0012,1.2)", "iw/2-(iw/zoom/2)", "ih/2-(ih/zoom/2)"
        vf = f"{base},zoompan=z='{z}':x='{x}':y='{y}':d={frames}:s={w}x{h}:fps={FPS},format=yuv420p"
        src = ["-loop", "1", "-i", image]
    run([*src, "-i", audio, "-t", f"{dur:.3f}", "-vf", vf,
         "-map", "0:v", "-map", "1:a", "-c:v", "libx264", "-preset", "medium", "-crf", "20",
         "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-ac", "2", "-shortest", out])


def run_stage(run_dir: Path, plan: dict, cfg: dict) -> Path:
    size = frame_size("long")
    timing = json.loads((run_dir / "timing.json").read_text(encoding="utf-8"))
    comp = run_dir / "compose"
    comp.mkdir(exist_ok=True)

    entries, offset, clip_files = [], 0.0, []
    for i, scene in enumerate(plan["scenes"], 1):
        key = f"{i:02}"
        audio = run_dir / "audio" / f"scene_{key}.mp3"
        dur = probe_duration(audio)
        sc = comp / f"scene_{key}.mp4"
        if not sc.exists():
            _scene_clip(scene, run_dir / "images" / f"scene_{key}.png",
                        run_dir / "clips" / f"scene_{key}.mp4", audio, dur, size, sc)
        clip_files.append(sc)
        for ch in timing[key]["chunks"]:
            entries.append({"text": ch["text"], "start": ch["start"] + offset,
                            "end": ch["end"] + offset, "highlight": ch.get("highlight", [])})
        offset += dur

    concat = run_dir / "concat.txt"
    concat.write_text("".join(f"file 'compose/{p.name}'\n" for p in clip_files), encoding="utf-8")
    joined = run_dir / "joined.mp4"
    run(["-f", "concat", "-safe", "0", "-i", "concat.txt", "-c", "copy", "joined.mp4"], cwd=run_dir)

    final = run_dir / "final.mp4"
    cmd = ["-i", "joined.mp4"]
    af = None
    vf_parts = []
    if cfg.get("subtitles", {}).get("enabled", True):
        build_ass(entries, cfg["subtitles"], size, run_dir / "subs.ass")
        vf_parts.append(f"subtitles=subs.ass:fontsdir={FONT_DIR}")
    bgm = (cfg.get("music") or {}).get("bgm_path")
    if bgm:
        cmd += ["-stream_loop", "-1", "-i", str(Path(bgm).resolve())]
        vol = cfg["music"].get("bgm_volume", 0.12)
        af = f"[1:a]volume={vol}[bg];[0:a][bg]amix=inputs=2:duration=first:normalize=0[a]"
    if vf_parts:
        cmd += ["-vf", ",".join(vf_parts)]
    if af:
        cmd += ["-filter_complex", af, "-map", "0:v", "-map", "[a]"]
    else:
        cmd += ["-map", "0:v", "-map", "0:a"]
    cmd += ["-c:v", "libx264", "-preset", "medium", "-crf", "19",
            "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", "final.mp4"]
    run(cmd, cwd=run_dir)
    return final
