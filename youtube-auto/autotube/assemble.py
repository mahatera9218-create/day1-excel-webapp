"""클립들을 같은 규격으로 맞추고, 이어 붙이고, 자막과 배경음악을 입힌다."""

import json
import re
import subprocess
from pathlib import Path


def probe_duration(path: Path) -> float:
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "json", str(path)],
        check=True, capture_output=True, text=True,
    ).stdout
    return float(json.loads(out)["format"]["duration"])


def _ts(seconds: float) -> str:
    ms = int(round(seconds * 1000))
    h, ms = divmod(ms, 3_600_000)
    m, ms = divmod(ms, 60_000)
    s, ms = divmod(ms, 1000)
    return f"{h:02}:{m:02}:{s:02},{ms:03}"


def _chunks(text: str, max_chars: int = 16) -> list[str]:
    """내레이션을 화면에 한 번에 보여줄 짧은 덩어리로 나눈다 (문장부호 → 띄어쓰기 순)."""
    pieces = [p.strip() for p in re.split(r"(?<=[.!?。…,])\s+", text.strip()) if p.strip()]
    out = []
    for piece in pieces:
        line = ""
        for word in piece.split():
            if line and len(line) + 1 + len(word) > max_chars:
                out.append(line)
                line = word
            else:
                line = f"{line} {word}".strip()
        if line:
            out.append(line)
    return out


def write_srt(scenes: list[dict], durations: list[float], dest: Path) -> None:
    """장면별 내레이션을 글자 수 비율로 시간 배분해 자막을 만든다.

    보이스오버는 장면 시작 직후 시작해 끝나기 조금 전에 마치는 경우가 많으므로
    앞뒤로 약간 여유를 둔다.
    """
    entries, start = [], 0.0
    for scene, dur in zip(scenes, durations):
        chunks = _chunks(scene["narration"])
        total = sum(len(c) for c in chunks) or 1
        t, span = start + 0.3, max(dur - 0.8, 1.0)
        for c in chunks:
            length = span * len(c) / total
            entries.append((t, t + length, c))
            t += length
        start += dur
    dest.write_text(
        "\n".join(f"{i}\n{_ts(a)} --> {_ts(b)}\n{text}\n" for i, (a, b, text) in enumerate(entries, 1)),
        encoding="utf-8",
    )


def assemble(run_dir: Path, plan: dict, cfg: dict) -> Path:
    shorts = cfg["video"]["format"] == "shorts"
    w, h = (1080, 1920) if shorts else (1920, 1080)
    clips = [run_dir / "clips" / f"scene_{i:02}.mp4" for i in range(1, len(plan["scenes"]) + 1)]
    missing = [c.name for c in clips if not c.exists()]
    if missing:
        raise SystemExit(f"[오류] 아직 만들어지지 않은 클립이 있습니다: {', '.join(missing)}")

    # 1) 해상도·프레임·오디오 규격 통일
    norm_dir = run_dir / "normalized"
    norm_dir.mkdir(exist_ok=True)
    normalized = []
    for clip in clips:
        out = norm_dir / clip.name
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", str(clip),
             "-vf", f"scale={w}:{h}:force_original_aspect_ratio=decrease,pad={w}:{h}:(ow-iw)/2:(oh-ih)/2,fps=24,format=yuv420p",
             "-af", "aresample=48000", "-ac", "2",
             "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-c:a", "aac", "-b:a", "192k", str(out)],
            check=True,
        )
        normalized.append(out)

    # 2) 이어 붙이기
    concat_list = run_dir / "concat.txt"
    concat_list.write_text("".join(f"file 'normalized/{p.name}'\n" for p in normalized), encoding="utf-8")
    joined = run_dir / "joined.mp4"
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", "concat.txt", "-c", "copy", "joined.mp4"],
        check=True, cwd=run_dir,
    )

    # 3) 자막 + 배경음악
    final = run_dir / "final.mp4"
    cmd = ["ffmpeg", "-y", "-loglevel", "error", "-i", "joined.mp4"]
    vf, af, maps = [], None, ["-map", "0:v"]
    sub = cfg.get("subtitles", {})
    if sub.get("enabled", True):
        write_srt(plan["scenes"], [probe_duration(p) for p in normalized], run_dir / "subs.srt")
        style = (f"FontName={sub.get('font', 'Malgun Gothic')},FontSize={sub.get('font_size', 16)},"
                 f"PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,BorderStyle=1,Outline=2,Shadow=0,"
                 f"Alignment=2,MarginV={sub.get('margin_v', 60)}")
        # 경로 이스케이프 문제를 피하려고 작업 폴더 기준 상대 경로를 쓴다
        vf.append(f"subtitles=subs.srt:force_style='{style}'")
    bgm = (cfg.get("music") or {}).get("bgm_path")
    if bgm:
        cmd += ["-stream_loop", "-1", "-i", str(Path(bgm).resolve())]
        af = f"[1:a]volume={cfg['music'].get('bgm_volume', 0.15)}[bg];[0:a][bg]amix=inputs=2:duration=first:normalize=0[a]"
    if vf:
        cmd += ["-vf", ",".join(vf)]
    if af:
        cmd += ["-filter_complex", af]
        maps += ["-map", "[a]"]
    else:
        maps += ["-map", "0:a"]
    cmd += maps + ["-c:v", "libx264", "-preset", "medium", "-crf", "18", "-c:a", "aac", "-b:a", "192k",
                   "-movflags", "+faststart", "final.mp4"]
    subprocess.run(cmd, check=True, cwd=run_dir)
    return final
