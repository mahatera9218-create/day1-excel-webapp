"""합성: 장면 클립 → 다양한 크로스페이드 전환 → 자막 → 색보정·그레인·빛입자 → 배경음악(더킹) → final.mp4"""

import json
from pathlib import Path

from ..config import FONT_DIR
from ..render.kenburns import FPS
from ..render.subtitles import build_ass
from ..render.util import frame_size, probe_duration, run

XFADE = 0.5  # 장면 전환 길이(초)
# 밋밋하지 않게, 장면마다 전환 방식을 순환 (은은한 것들 위주)
TRANSITIONS = ["fade", "dissolve", "fadeblack", "smoothleft", "smoothright", "wiperight", "fadegrays"]
FX_DIR = FONT_DIR.parent / "fx"
MOTES = FX_DIR / "motes.png"  # 떠다니는 빛 입자(보케/먼지) 오버레이


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
         "-map", "0:v", "-map", "1:a", "-c:v", "libx264", "-preset", "veryfast", "-crf", "20",
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
        # 크로스페이드로 겹치는 만큼 시작 시각이 앞당겨진다
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

    # ---- 입력 순서를 먼저 정해 인덱스를 고정한다 ----
    inputs = []
    for p in clip_files:
        inputs += ["-i", f"compose/{p.name}"]
    next_idx = n
    bgm_idx = motes_idx = None
    if bgm:
        inputs += ["-stream_loop", "-1", "-i", str(Path(bgm).resolve())]
        bgm_idx = next_idx; next_idx += 1
    use_motes = MOTES.exists()
    if use_motes:
        inputs += ["-loop", "1", "-i", str(MOTES.resolve())]
        motes_idx = next_idx; next_idx += 1

    parts = []
    # ---- 영상: 장면 전환(종류 순환) ----
    vprev, sb = "[0:v]", 0.0
    for k in range(1, n):
        sb += durs[k - 1]
        off = sb - k * XFADE
        tr = TRANSITIONS[(k - 1) % len(TRANSITIONS)]
        parts.append(f"{vprev}[{k}:v]xfade=transition={tr}:duration={XFADE}:offset={off:.3f}[v{k}]")
        vprev = f"[v{k}]"
    # ---- 오디오: 내레이션 크로스페이드 ----
    aprev = "[0:a]"
    for k in range(1, n):
        parts.append(f"{aprev}[{k}:a]acrossfade=d={XFADE}[a{k}]")
        aprev = f"[a{k}]"

    # ---- 영상 마감: 시작/끝 페이드 + 자막 + 영화 같은 색보정·비네트·필름 그레인 ----
    vchain = f"{vprev}fade=t=in:st=0:d=0.6,fade=t=out:st={max(0.0, total-0.6):.3f}:d=0.6"
    if subs_on:
        vchain += f",subtitles=subs.ass:fontsdir={FONT_DIR}"
    # 색보정+비네트+가벼운(공간) 그레인. 시간축(allf=t) 그레인은 CI에서 매우 느려 제거.
    vchain += ",eq=contrast=1.05:saturation=1.08:gamma=0.98,vignette=PI/6,noise=alls=5"
    # What-if(가상 시나리오)는 신뢰·광고 안전을 위해 작은 상시 라벨을 항상 표기
    if plan.get("content_type") == "what_if":
        fnt = FONT_DIR / "NotoSansKR.ttf"
        vchain += (f",drawtext=fontfile='{fnt}':text='WHAT-IF SCENARIO':fontcolor=white@0.55:"
                   f"fontsize=22:x=w-tw-28:y=h-th-26:box=1:boxcolor=black@0.28:boxborderw=8")

    if motes_idx is not None:
        # 프레임보다 큰 빛입자 레이어를 천천히 떠다니게 오버레이 → 정지화면에 생동감
        parts.append(f"{vchain}[vbase]")
        w2, h2 = int(w * 1.2), int(h * 1.2)
        dx, dy = (w2 - w) // 2, (h2 - h) // 2
        parts.append(f"[{motes_idx}:v]scale={w2}:{h2},format=rgba[mz]")
        parts.append(
            f"[vbase][mz]overlay="
            f"x='-{dx}+90*sin(t*0.08)':y='-{dy}+70*cos(t*0.06)':format=auto[vout]"
        )
    else:
        parts.append(f"{vchain}[vout]")

    # ---- 오디오: 배경음악을 내레이션 아래로 자동 더킹(sidechaincompress) ----
    if bgm_idx is not None:
        vol = cfg["music"].get("bgm_volume", 0.20)
        parts.append(f"{aprev}asplit=2[nar][key]")
        parts.append(f"[{bgm_idx}:a]volume={vol}[bgv]")
        parts.append(f"[bgv][key]sidechaincompress=threshold=0.03:ratio=8:attack=20:release=400[duck]")
        parts.append(f"[nar][duck]amix=inputs=2:duration=first:normalize=0[aout]")
        amap = "[aout]"
    else:
        amap = aprev

    cmd = inputs + ["-filter_complex", ";".join(parts), "-map", "[vout]", "-map", amap,
                    "-c:v", "libx264", "-preset", "veryfast", "-crf", "20", "-threads", "0",
                    "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", "final.mp4"]
    run(cmd, cwd=run_dir)
    return run_dir / "final.mp4"
