"""에피소드 결과물을 폰에서 볼 수 있는 미리보기 웹페이지(site/)로 만든다.

사용법: python -m autotube.build_preview <episode_dir> <site_dir> [channel_title]
GitHub Pages 로 배포되어 링크 하나로 영상·그림·쇼츠를 바로 본다.
"""

import html
import json
import shutil
import sys
from pathlib import Path


def build(ep: Path, site: Path, channel_title: str = "") -> None:
    media = site / "media"
    shorts_dir = media / "shorts"
    media.mkdir(parents=True, exist_ok=True)
    shorts_dir.mkdir(parents=True, exist_ok=True)

    plan = json.loads((ep / "plan.json").read_text(encoding="utf-8"))

    def copy(src: Path, dst: Path):
        if src.exists():
            shutil.copy(src, dst)

    copy(ep / "final.mp4", media / "final.mp4")
    copy(ep / "thumbnail.jpg", media / "thumbnail.jpg")
    images = sorted((ep / "images").glob("*.png")) if (ep / "images").exists() else []
    for img in images:
        copy(img, media / img.name)
    shorts = sorted((ep / "shorts").glob("*.mp4")) if (ep / "shorts").exists() else []
    for s in shorts:
        copy(s, shorts_dir / s.name)

    title = html.escape(plan.get("title", ep.name))
    topic = html.escape(plan.get("topic", ""))
    desc = html.escape(plan.get("description", "")).replace("\n", "<br>")

    img_cards = "\n".join(
        f'<figure><img loading="lazy" src="media/{i.name}"><figcaption>{n}</figcaption></figure>'
        for n, i in enumerate(images, 1)
    )
    short_cards = "\n".join(
        f'<video controls preload="metadata" src="media/shorts/{s.name}"></video>' for s in shorts
    )

    page = f"""<!doctype html>
<html lang="ko"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} · 미리보기</title>
<style>
  :root {{ color-scheme: dark; }}
  * {{ box-sizing: border-box; }}
  body {{ margin:0; background:#0e0f13; color:#e8e8ea; font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif; }}
  .wrap {{ max-width:960px; margin:0 auto; padding:16px; }}
  h1 {{ font-size:1.25rem; line-height:1.4; margin:.6rem 0; }}
  .topic {{ color:#9aa0aa; font-size:.9rem; margin-bottom:1rem; }}
  video, img {{ width:100%; border-radius:12px; background:#000; display:block; }}
  .main video {{ aspect-ratio:16/9; }}
  h2 {{ font-size:1rem; margin:1.6rem 0 .6rem; color:#c7ccd4; }}
  .grid {{ display:grid; grid-template-columns:repeat(auto-fill,minmax(150px,1fr)); gap:10px; }}
  figure {{ margin:0; }}
  figcaption {{ font-size:.75rem; color:#9aa0aa; padding:4px 2px; }}
  .shorts {{ display:grid; grid-template-columns:repeat(auto-fill,minmax(160px,1fr)); gap:10px; }}
  .shorts video {{ aspect-ratio:9/16; }}
  .desc {{ color:#b8bdc6; font-size:.9rem; line-height:1.6; background:#15171d; padding:12px 14px; border-radius:12px; }}
  footer {{ color:#6b7280; font-size:.75rem; margin:2rem 0 1rem; text-align:center; }}
</style></head>
<body><div class="wrap">
  <div class="topic">{html.escape(channel_title)} · 미리보기</div>
  <h1>{title}</h1>
  <div class="topic">{topic}</div>
  <div class="main"><video controls preload="metadata" poster="media/thumbnail.jpg" src="media/final.mp4"></video></div>
  <h2>설명</h2>
  <div class="desc">{desc}</div>
  <h2>썸네일</h2>
  <img src="media/thumbnail.jpg" alt="thumbnail">
  <h2>장면 그림 ({len(images)})</h2>
  <div class="grid">{img_cards}</div>
  <h2>쇼츠 ({len(shorts)})</h2>
  <div class="shorts">{short_cards}</div>
  <footer>autotube preview</footer>
</div></body></html>"""
    (site / "index.html").write_text(page, encoding="utf-8")
    (site / ".nojekyll").write_text("", encoding="utf-8")
    print(f"미리보기 페이지 생성: {site/'index.html'} (그림 {len(images)}, 쇼츠 {len(shorts)})")


if __name__ == "__main__":
    ep = Path(sys.argv[1])
    site = Path(sys.argv[2])
    build(ep, site, sys.argv[3] if len(sys.argv) > 3 else "")
