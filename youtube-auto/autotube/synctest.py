"""자막 싱크만 '무료로' 확인하는 테스트 클립 — Pika 없이(돈 0원).

목소리(edge-tts, 무료) + 실제 단어 타임스탬프 자막 + 단색 배경만으로 짧은 영상을 만든다.
GitHub 워크플로(synctest.yml)가 이걸 돌려 GitHub Pages 로 올리면 폰에서 바로 보고
"자막이 목소리와 맞나" 확인할 수 있다. 숫자가 섞인 문장으로 일부러 빡세게 테스트한다.

사용: python -m autotube.synctest <출력폴더(site)>
"""

import sys
from pathlib import Path

from .config import FONT_DIR
from .engines.edge import EdgeEngine
from .render.subtitles import build_ass
from .render.util import probe_duration, run

SAMPLE = ("In July 1518, a woman stepped into the street and began to dance. "
          "Within four days, thirty more had joined her. "
          "By the end of the month, nearly four hundred people were dancing, "
          "and some of them could not stop.")


def main(out_dir: str) -> int:
    site = Path(out_dir)
    site.mkdir(parents=True, exist_ok=True)
    cfg = {
        "engines": {"tts": "edge", "edge_voice": "en-US-ChristopherNeural"},
        "subtitles": {"enabled": True, "font": "Noto Sans KR", "font_size": 46,
                      "primary_color": "FFFFFF", "highlight_color": "FFD400", "outline": 4},
    }
    eng = EdgeEngine(cfg)
    audio = site / "sync.mp3"
    print("목소리 생성(edge-tts, 무료)...", flush=True)
    timing = eng.voice({"narration": SAMPLE, "highlight": ["could not stop", "four hundred"]}, audio)
    dur = probe_duration(audio)

    # ── 진단: edge 가 준 '원시 단어 시각' vs 실제 음성 길이 vs 자막 줄 ──
    words = getattr(eng, "last_words", [])
    print("=== SYNC DEBUG ===", flush=True)
    print(f"mp3 실제 길이(probe) = {dur:.3f}s")
    if words:
        print(f"단어 {len(words)}개. 첫 단어 offset={words[0][1]:.3f}s  "
              f"마지막 단어 끝={words[-1][2]:.3f}s")
        for t, s, e in words[:6]:
            print(f"   word  {s:7.3f}-{e:7.3f}  {t!r}")
        print(f"   ... (마지막) {words[-1][0]!r} {words[-1][1]:.3f}-{words[-1][2]:.3f}")
    print("자막 줄:")
    for c in timing["chunks"]:
        print(f"   line  {c['start']:7.3f}-{c['end']:7.3f}  {c['text']!r}")
    print("=== /SYNC DEBUG ===", flush=True)

    ass = site / "sync.ass"
    build_ass(timing["chunks"], cfg["subtitles"], (1280, 720), ass)

    mp4 = site / "sync_test.mp4"
    print("자막 입힌 테스트 영상 합성(ffmpeg, 무료)...", flush=True)
    run(["-f", "lavfi", "-i", f"color=c=0x15121a:s=1280x720:d={dur + 0.3:.2f}",
         "-i", str(audio),
         "-vf", f"subtitles={ass.name}:fontsdir={FONT_DIR}",
         "-map", "0:v", "-map", "1:a",
         "-c:v", "libx264", "-preset", "veryfast", "-crf", "22",
         "-c:a", "aac", "-b:a", "192k", "-shortest", "-movflags", "+faststart", mp4.name],
        cwd=site)

    (site / "index.html").write_text(
        "<!doctype html><meta charset=utf-8>"
        "<meta name=viewport content='width=device-width,initial-scale=1'>"
        "<body style='margin:0;background:#111;color:#eee;font-family:system-ui,sans-serif'>"
        "<h3 style='padding:14px 16px 4px'>자막 싱크 테스트</h3>"
        "<p style='padding:0 16px;color:#aab'>소리 켜고 보세요. 자막이 목소리와 딱 맞나요?</p>"
        "<video src='sync_test.mp4' controls autoplay playsinline style='width:100%;max-width:900px;display:block;margin:0 auto'></video>"
        "<p style='padding:14px 16px;color:#aab'>안 맞으면 “몇 초 빠르다/느리다” 또는 “어디서부터 밀린다”만 알려주세요. 돈 안 드니 맞을 때까지 고칩니다.</p>"
        "</body>", encoding="utf-8")
    print(f"완료: {mp4}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1] if len(sys.argv) > 1 else "site"))
