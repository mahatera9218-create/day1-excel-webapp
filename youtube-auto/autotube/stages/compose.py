"""합성: 장면별 클립 → 크로스페이드 전환으로 이어붙이기 → 강조 자막 → 배경음악 → final.mp4"""

import json
from pathlib import Path

from ..config import FONT_DIR
from ..render.kenburns import FPS
from ..render.subtitles import build_ass
from ..render.util import frame_size, probe_duration, run

XFADE = 0.5  # 장면 전환(디졸브) 길이(초)


def _kenburns_vf(idx: int, frames: int, w: int, h: int) -> str:
    """장면마다 다른 카메라 무빙 (확대/축소/좌우 팬)."""
    base = f"scale={w*2}:{h*2}:force_original_aspect_ratio=increase,crop={w*2}:{h*2}"
    cxy = "x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)'"
    v = idx % 4
    if v == 0:    # 천천히 확대
        z = f"1.0+0.30*on/{frames}"
        xy = cxy
    elif v == 1:  # 천천히 축소
        z = f"1.30-0.30*on/{frames}"
        xy = cxy
    elif v == 2:  # 좌 → 우 팬
        z = "1.14"
        xy = f"x='(iw-iw/zoom)*on/{frames}':y='ih/2-(ih/zoom/2)'"
    else:         # 우 → 좌 팬
        z = "1.14"
        xy = f"x='(iw-iw/zoom)*(1-on/{frames})':y='ih/2-(ih/zoom/2)'"
    return f"{base},zoompan=z='{z}':{xy}:d={frames}:s={w}x{h}:fps={FPS},format=yuv420p"


def _scene_clip(scene: dict, idx: int, image: Path, clip: Path | None, audio: Path,
                dur: float, size: tuple[int, int], out: Path) -> None:
    w, h = size
    if clip and clip.exists():
        vf = (f"scale={w}:{h}:force_original_aspect_ratio=decrease,"
              f"pad={w}:{h}:(ow-iw)/2:(oh-ih)/2,fps={FPS},format=yuv420p")
        src = ["-stream_loop", "-1", "-i", str(clip)]
    else:
        vf = _kenburns_vf(idx, max(int(dur * FPS), 1), w, h)
        src = ["-loop", "1", "-i", str(image)]
    run([*src, "-i", str(audio), "-t", f"{dur:.3f}", "-vf", vf,
         "-map", "0:v", "-map", "1:a", "-c:v", "libx264", "-preset", "medium", "-crf", "20",
         "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-ac", "2", "-shortest", str(out)])


def run_stage(run_dir: Path, plan: dict, cfg: dict) -> Path:
    w, h = size = frame_size("long")
    timing = json.loads((run_dir / "timing.json").read_text(encoding="utf-8"))
    comp = run_dir / "compose"
    comp.mkdir(exist_ok=True)

    durs, clip_files, entries = [], [], []
    cum = 0.0
    for i, scene in enumerate(plan["scenes"], 1):
        key = f"{i:02}"
        audio = run_dir / "audio" / f"scene_{key}.mp3"
        dur = probe_duration(audio)
        sc = comp / f"scene_{key}.mp4"
        if not sc.exists():
            _scene_clip(scene, i - 1, run_dir / "images" / f"scene_{key}.png",
                        run_dir / "clips" / f"scene_{key}.mp4", audio, dur, size, sc)
        clip_files.append(sc)
        # 크로스페이드로 겹치는 만큼 시작 시각이 앞당겨진다: start_i = cum - i*XFADE
        soff = cum - (i - 1) * XFADE
        for ch in timing[key]["chunks"]:
            entries.append({"text": ch["text"], "start": round(ch["start"] + soff, 2),
                            "end": round(ch["end"] + soff, 2), "highlight": ch.get("highlight", [])})
        durs.append(dur)
        cum += dur

    n = len(clip_files)
    total = sum(durs) - (n - 1) * XFADE
    subs_on = cfg.get("subtitles", {}).get("enabled", True)
    if subs_on:
        build_ass(entries, cfg["subtitles"], size, run_dir / "subs.ass")
    bgm = (cfg.get("music") or {}).get("bgm_path")

    # ---- 필터 그래프: 영상 크로스페이드 + 오디오 크로스페이드 (+자막 +배경음악) ----
    inputs, parts = [], []
    for p in clip_files:
        inputs += ["-i", f"compose/{p.name}"]
    vprev, aprev, sb = "[0:v]", "[0:a]", 0.0
    for k in range(1, n):
        sb += durs[k - 1]
        off = sb - k * XFADE
        parts.append(f"{vprev}[{k}:v]xfade=transition=fade:duration={XFADE}:offset={off:.3f}[v{k}]")
        parts.append(f"{aprev}[{k}:a]acrossfade=d={XFADE}[a{k}]")
        vprev, aprev = f"[v{k}]", f"[a{k}]"
    vchain = f"{vprev}fade=t=in:st=0:d=0.6,fade=t=out:st={max(0.0, total-0.6):.3f}:d=0.6"
    if subs_on:
        vchain += f",subtitles=subs.ass:fontsdir={FONT_DIR}"
    parts.append(f"{vchain}[vout]")
    if bgm:
        inputs += ["-stream_loop", "-1", "-i", str(Path(bgm).resolve())]
        vol = cfg["music"].get("bgm_volume", 0.12)
        parts.append(f"[{n}:a]volume={vol}[bg];{aprev}[bg]amix=inputs=2:duration=first:normalize=0[aout]")
        amap = "[aout]"
    else:
        amap = aprev

    cmd = inputs + ["-filter_complex", ";".join(parts), "-map", "[vout]", "-map", amap,
                    "-c:v", "libx264", "-preset", "medium", "-crf", "19",
                    "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", "final.mp4"]
    run(cmd, cwd=run_dir)
    return run_dir / "final.mp4"
