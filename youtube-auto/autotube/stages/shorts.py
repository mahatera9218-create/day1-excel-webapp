"""쇼츠: '전용 티저 대본'으로 유입용 세로 영상을 만든다.

각 쇼츠는 그 자체로 완결된 티저다 — 강한 훅 → 궁금증 → (답은 안 주고) CTA.
plan["shorts"] = [{ "narration": "...", "scenes": [본편 장면번호들], "highlight": [...],
                    "cta": "..."(선택) }, ...]
- 나레이션은 무료 목소리(edge)로 새로 읽고, 그림은 본편에서 이미 만든 걸 재사용(추가비용 0).
- 세로 9:16, 큰 자막, 켄번스+전환, what-if면 라벨, 끝 3초 CTA 카드.
"""

from pathlib import Path

from ..config import FONT_DIR
from ..engines import Engines
from ..render.kenburns import FPS
from ..render.subtitles import build_ass
from ..render.util import probe_duration, run
from .compose import XFADE, _kenburns_vf

DEFAULT_CTA = "▶  FULL STORY — link in description"
VERBAL_CTA = "The full story is in the description below."  # 쇼츠 끝에 음성으로도 유도


def _esc(t: str) -> str:
    return t.replace("\\", "\\\\").replace(":", "\\:").replace("'", "’").replace("%", "\\%")


def _seg_clip(img: Path, idx: int, dur: float, size: tuple[int, int], out: Path) -> None:
    w, h = size
    vf = _kenburns_vf(idx, max(int(dur * FPS), 1), w, h)
    run(["-loop", "1", "-i", str(img), "-t", f"{dur:.3f}", "-vf", vf, "-an",
         "-c:v", "libx264", "-preset", "veryfast", "-crf", "22", str(out)])


def _seg_from_clip(clip: Path, dur: float, size: tuple[int, int], out: Path) -> None:
    """본편에서 이미 만든 '움직이는 클립'을 세로로 꽉 채워 재활용(추가 비용 0, 쇼츠도 실제로 움직임)."""
    w, h = size
    vf = (f"scale={w}:{h}:force_original_aspect_ratio=increase,crop={w}:{h},"
          f"fps={FPS},format=yuv420p")
    run(["-stream_loop", "-1", "-i", str(clip), "-t", f"{dur:.3f}", "-vf", vf, "-an",
         "-c:v", "libx264", "-preset", "veryfast", "-crf", "22", str(out)])


def run_stage(run_dir: Path, plan: dict, cfg: dict) -> list[Path]:
    sh = cfg.get("shorts", {})
    specs = plan.get("shorts") or []
    if not sh.get("enabled", True) or not specs:
        return []
    size = (1080, 1920)
    w, h = size
    out_dir = run_dir / "shorts"
    out_dir.mkdir(exist_ok=True)
    engines = Engines(cfg)
    fnt = FONT_DIR / "NotoSansKR.ttf"
    sub_cfg = {**cfg["subtitles"], "font_size": 64, "margin_v": 360}
    is_whatif = plan.get("content_type") == "what_if"
    made = []

    for n, short in enumerate(specs[: sh.get("count", 2)], 1):
        final = out_dir / f"short_{n:02}.mp4"
        if final.exists():
            made.append(final)
            continue

        # 1) 티저 나레이션 → 무료 목소리(한 번 호출로 mp3 + 자막 타이밍 둘 다)
        #    끝에 '설명 링크' 유도 멘트를 자동으로 붙여 음성·자막·끝카드가 맞물리게 한다.
        narr = short["narration"].strip()
        if narr and narr[-1] not in ".!?":
            narr += "."
        narr = f"{narr} {VERBAL_CTA}"
        saud = out_dir / f"short_{n:02}.mp3"
        tdict = engines.voice({"narration": narr, "highlight": short.get("highlight", [])}, saud)
        dur = probe_duration(saud)
        ass = out_dir / f"short_{n:02}.ass"
        build_ass(tdict["chunks"], sub_cfg, size, ass)

        # 2) 그림: 본편 장면 재사용. 움직이는 클립이 있으면 그걸(무료 움직임), 없으면 스틸.
        refs = [int(s) for s in (short.get("scenes") or []) if str(s).isdigit()]
        srcs = []  # (kind, path)
        for r in refs:
            vclip = run_dir / "clips" / f"scene_{r:02}.mp4"
            still = run_dir / "images" / f"scene_{r:02}.png"
            if vclip.exists():
                srcs.append(("video", vclip))
            elif still.exists():
                srcs.append(("still", still))
        if not srcs:
            srcs = [("still", run_dir / "images" / "scene_01.png")]
        nimg = len(srcs)

        # 3) 장면별 세로 클립 (전환 겹침만큼 약간 길게) — 모션 장면은 실제 영상, 그 외는 켄번스
        seg = dur / nimg + (XFADE if nimg > 1 else 0)
        clips = []
        for k, (kind, path) in enumerate(srcs):
            sc = out_dir / f"_s{n}_{k:02}.mp4"
            if not sc.exists():
                if kind == "video":
                    _seg_from_clip(path, seg, size, sc)
                else:
                    _seg_clip(path, k, seg, size, sc)
            clips.append(sc)

        # 4) 합성: 전환 + 색보정/비네트 + 자막 + (what-if 라벨) + 끝 CTA + 오디오
        inputs, parts = [], []
        for c in clips:
            inputs += ["-i", c.name]
        inputs += ["-i", saud.name]
        aidx = nimg
        vprev = "[0:v]"
        for k in range(1, nimg):
            off = k * (seg - XFADE)
            parts.append(f"{vprev}[{k}:v]xfade=transition=fade:duration={XFADE}:offset={off:.3f}[v{k}]")
            vprev = f"[v{k}]"
        vchain = (f"{vprev}fade=t=in:st=0:d=0.4,"
                  f"eq=contrast=1.08:saturation=1.16:gamma=0.98,vignette=PI/6,"
                  f"subtitles={ass.name}:fontsdir={FONT_DIR}")
        if is_whatif:
            vchain += (f",drawtext=fontfile='{fnt}':text='WHAT-IF SCENARIO':fontcolor=white@0.55:"
                       f"fontsize=30:x=w-tw-28:y=36:box=1:boxcolor=black@0.28:boxborderw=8")
        cta = _esc(short.get("cta") or DEFAULT_CTA)
        cta_from = max(0.0, dur - 3.0)
        vchain += (f",drawtext=fontfile='{fnt}':text='{cta}':fontcolor=white:fontsize=58:"
                   f"borderw=6:bordercolor=black@0.85:x=(w-tw)/2:y=h*0.68:"
                   f"box=1:boxcolor=black@0.35:boxborderw=18:enable='gte(t,{cta_from:.2f})'")
        parts.append(f"{vchain}[vout]")

        cmd = inputs + ["-filter_complex", ";".join(parts), "-map", "[vout]", "-map", f"{aidx}:a",
                        "-c:v", "libx264", "-preset", "veryfast", "-crf", "21", "-threads", "0",
                        "-c:a", "aac", "-b:a", "192k", "-shortest", "-movflags", "+faststart", final.name]
        run(cmd, cwd=out_dir)
        for c in clips:  # 중간 조각 정리 (업로드 키트가 최종본만 집도록)
            c.unlink(missing_ok=True)
        made.append(final)
    return made
