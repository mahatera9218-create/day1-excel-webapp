"""화풍 미리보기: 같은 역사 장면을 여러 그림체로 1장씩 생성하고 비교 웹페이지를 만든다.

사용: python -m autotube.style_preview <출력폴더(site)>
- 영상은 만들지 않는다(이미지 N장만) → 빠르고 크레딧 소량.
- GitHub Actions(style_preview.yml)에서 PIKA_API_KEY(시크릿)로 실행 → Pages로 배포.
"""

import sys
from pathlib import Path

import yaml

from .engines import Engines

# 비교에 쓸 대표 장면(인물 얼굴 + 배경 + 분위기가 다 드러나는 역사 한 컷)
PROMPT = ("a Roman emperor on a marble throne at a tense dramatic moment, intense "
          "expression, torchlit hall, dust in the air, cinematic composition")

STYLES = [
    ("hyperreal", "하이퍼리얼 시네마틱",
     "hyperreal cinematic film still, dramatic chiaroscuro lighting, 35mm, shallow "
     "depth of field, photorealistic, moody, no text, no logos"),
    ("clean3d", "클린 3D 렌더",
     "clean stylized 3D render, soft studio lighting, subtle low-poly, Pixar-like "
     "warmth, vibrant, crisp detail, no text, no logos"),
    ("graphic", "볼드 그래픽 일러스트",
     "bold modern graphic illustration, high contrast, dramatic poster art, clean "
     "strong shapes, striking limited color, cinematic, no text, no logos"),
    ("painterly", "현재(따뜻한 그림체)",
     "cinematic historical illustration, warm painterly tone, era-accurate detail, "
     "documentary mood, dramatic natural lighting, no text, no logos"),
]

PAGE = """<!doctype html><html lang="ko"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Mr.Untold — 화풍 비교</title>
<style>
 body{{margin:0;background:#0d0d10;color:#f2f2f4;font-family:-apple-system,system-ui,sans-serif}}
 header{{padding:22px 18px 6px}} h1{{font-size:20px;margin:0}} p.sub{{color:#9aa;margin:6px 0 0;font-size:13px}}
 .card{{margin:18px;background:#17171c;border-radius:16px;overflow:hidden;border:1px solid #26262e}}
 .card img{{width:100%;display:block}}
 .meta{{padding:12px 16px 16px}} .tag{{font-size:12px;color:#8bd;letter-spacing:.5px}}
 .name{{font-size:17px;font-weight:700;margin:4px 0 2px}} .desc{{font-size:13px;color:#aab;line-height:1.5}}
</style></head><body>
<header><h1>🎨 화풍 비교 — 같은 장면, 다른 그림체</h1>
<p class="sub">맘에 드는 번호를 저에게 알려주세요. 그걸로 채널 기본 화풍을 박습니다.</p></header>
{cards}
</body></html>"""

CARD = """<div class="card"><img src="img/{key}.png" alt="{name}">
<div class="meta"><div class="tag">#{i}</div><div class="name">{name}</div>
<div class="desc">{desc}</div></div></div>"""


def main(out_dir: str) -> int:
    site = Path(out_dir)
    (site / "img").mkdir(parents=True, exist_ok=True)
    cfg = yaml.safe_load(open("channels/world/channel.yaml"))
    cfg["engines"]["mode"] = "real"
    cfg["_dir"] = Path("channels/world")
    eng = Engines(cfg)

    cards = []
    for i, (key, name, style) in enumerate(STYLES, 1):
        dst = site / "img" / f"{key}.png"
        print(f"[{i}/{len(STYLES)}] {name} 생성 중...", flush=True)
        try:
            eng.image({"image_prompt": PROMPT, "_style": style, "_label": key}, dst)
            print(f"   -> {dst} ({dst.stat().st_size} bytes)")
            cards.append(CARD.format(i=i, key=key, name=name, desc=f"{style}"))
        except Exception as e:  # noqa: BLE001
            print(f"   !! 실패: {e}")
            cards.append(f'<div class="card"><div class="meta"><div class="name">'
                         f'#{i} {name} (생성 실패)</div><div class="desc">{e}</div></div></div>')
    (site / "index.html").write_text(PAGE.format(cards="\n".join(cards)), encoding="utf-8")
    print(f"완료: {site/'index.html'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1] if len(sys.argv) > 1 else "site"))
