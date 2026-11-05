"""이번에 만들어진 편들을 '업로드 키트' 목록 페이지(site/)로 만든다.

목록형: 썸네일 + 제목만 한 줄씩. 항목을 누르면 펼쳐서
영상/썸네일/쇼츠 다운로드 + 제목·설명·태그 복사 + '목록에서 제거'(GitHub status.json 삭제).

사용법: python -m autotube.build_preview <channel_episodes_dir> <site_dir> <channel_title> <repo> <branch> <ep_path_prefix>
"""

import html
import json
import shutil
import sys
from pathlib import Path

AI_NOTICE = "This video's visuals and narration were created with AI."


def _item(ep: Path, media: Path, repo: str, branch: str, ep_prefix: str) -> str:
    plan = json.loads((ep / "plan.json").read_text(encoding="utf-8"))
    folder = ep.name
    dst = media / folder
    (dst / "shorts").mkdir(parents=True, exist_ok=True)
    for name in ("final.mp4", "thumbnail.jpg"):
        if (ep / name).exists():
            shutil.copy(ep / name, dst / name)
    shorts = sorted((ep / "shorts").glob("*.mp4")) if (ep / "shorts").exists() else []
    for s in shorts:
        shutil.copy(s, dst / "shorts" / s.name)

    title = plan.get("title", folder)
    desc = plan.get("description", "").strip() + "\n\n" + AI_NOTICE
    tags = ", ".join(plan.get("tags", []))
    e = html.escape
    remove_url = f"https://github.com/{repo}/delete/{branch}/{ep_prefix}/{folder}/status.json"
    short_dl = "".join(
        f'<a class="dl alt" download href="media/{folder}/shorts/{s.name}">⬇ 쇼츠 {n}</a>'
        for n, s in enumerate(shorts, 1)
    )
    return f"""
  <details class="item">
    <summary>
      <img class="thumb" loading="lazy" src="media/{folder}/thumbnail.jpg" alt="">
      <span class="title">{e(title)}</span>
      <span class="chev">▸</span>
    </summary>
    <div class="detail">
      <video controls preload="none" poster="media/{folder}/thumbnail.jpg" src="media/{folder}/final.mp4"></video>
      <div class="row">
        <a class="dl" download href="media/{folder}/final.mp4">⬇ 영상</a>
        <a class="dl alt" download href="media/{folder}/thumbnail.jpg">⬇ 썸네일</a>
        {short_dl}
      </div>
      <div class="box"><button class="copy" data-t="t-{folder}">제목 복사</button><pre id="t-{folder}">{e(title)}</pre></div>
      <div class="box"><button class="copy" data-t="d-{folder}">설명 복사</button><pre id="d-{folder}">{e(desc)}</pre></div>
      <div class="box"><button class="copy" data-t="g-{folder}">태그 복사</button><pre id="g-{folder}">{e(tags)}</pre></div>
      <a class="remove" href="{remove_url}" target="_blank" rel="noopener">✓ 업로드함 — 목록에서 제거</a>
    </div>
  </details>"""


def build(channel_dir: Path, site: Path, channel_title: str,
          repo: str, branch: str, ep_prefix: str) -> None:
    media = site / "media"
    media.mkdir(parents=True, exist_ok=True)
    eps = sorted(d for d in channel_dir.glob("*") if (d / "final.mp4").exists())
    items = "".join(_item(ep, media, repo, branch, ep_prefix) for ep in eps)
    empty = "" if eps else '<p class="muted">이번에 만들어진 영상이 없습니다.</p>'

    page = f"""<!doctype html>
<html lang="ko"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(channel_title)} · 업로드 대기</title>
<style>
  :root {{ color-scheme: dark; }}
  * {{ box-sizing: border-box; }}
  body {{ margin:0; background:#0e0f13; color:#e8e8ea; font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif; }}
  .wrap {{ max-width:820px; margin:0 auto; padding:14px; }}
  h1 {{ font-size:1.15rem; margin:.3rem 0 .2rem; }}
  .muted {{ color:#9aa0aa; font-size:.85rem; }}
  .hint {{ color:#9aa0aa; font-size:.82rem; margin:.2rem 0 1rem; }}

  .item {{ border:1px solid #23262e; border-radius:12px; margin:8px 0; background:#14161b; overflow:hidden; }}
  summary {{ display:flex; align-items:center; gap:12px; padding:10px; cursor:pointer; list-style:none; }}
  summary::-webkit-details-marker {{ display:none; }}
  .thumb {{ width:120px; height:68px; object-fit:cover; border-radius:8px; background:#000; flex:none; }}
  .title {{ flex:1; font-size:.95rem; font-weight:600; line-height:1.35;
            display:-webkit-box; -webkit-line-clamp:2; -webkit-box-orient:vertical; overflow:hidden; }}
  .chev {{ color:#6b7280; transition:transform .15s; flex:none; }}
  details[open] .chev {{ transform:rotate(90deg); }}

  .detail {{ padding:0 12px 14px; }}
  video {{ width:100%; border-radius:10px; background:#000; aspect-ratio:16/9; }}
  .row {{ display:flex; gap:8px; flex-wrap:wrap; margin:10px 0; }}
  .dl {{ background:#2563eb; color:#fff; text-decoration:none; padding:11px 14px; border-radius:10px; font-weight:600; font-size:.9rem; }}
  .dl.alt {{ background:#334155; }}
  .box {{ position:relative; background:#0e0f13; border:1px solid #23262e; border-radius:10px; padding:42px 12px 12px; margin:8px 0; }}
  .box pre {{ margin:0; white-space:pre-wrap; word-break:break-word; font-size:.86rem; color:#dfe3ea; }}
  .copy {{ position:absolute; top:8px; right:8px; background:#334155; color:#fff; border:0; border-radius:8px; padding:6px 10px; font-size:.78rem; cursor:pointer; }}
  .remove {{ display:inline-block; margin-top:6px; background:#7f1d1d; color:#fff; text-decoration:none; padding:11px 14px; border-radius:10px; font-weight:600; font-size:.9rem; }}
  footer {{ color:#6b7280; font-size:.75rem; margin:2rem 0 1rem; text-align:center; }}
</style></head>
<body><div class="wrap">
  <h1>{html.escape(channel_title)} · 업로드 대기 ({len(eps)})</h1>
  <div class="hint">항목을 눌러 펼친 뒤 받아서 올리고, 올린 건 빨간 "목록에서 제거"를 누르세요.</div>
  {empty}
  <div class="list">{items}</div>
  <footer>autotube upload kit</footer>
</div>
<script>
  for (const b of document.querySelectorAll('.copy')) {{
    b.onclick = (ev) => {{ ev.preventDefault();
      const el=document.getElementById(b.dataset.t);
      navigator.clipboard.writeText(el.innerText).then(()=>{{const o=b.textContent;b.textContent='복사됨';setTimeout(()=>b.textContent=o,1200);}}); }};
  }}
</script>
</body></html>"""
    (site / "index.html").write_text(page, encoding="utf-8")
    (site / ".nojekyll").write_text("", encoding="utf-8")
    print(f"업로드 키트 생성: {site/'index.html'} (편 {len(eps)})")


if __name__ == "__main__":
    build(Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6])
