"""게임 캐릭터 세트를 Pika(api.dev.pika.art, Seedream)로 생성한다.
GitHub Actions 에서 PIKA_API_KEY(이미 있는 비밀키)로 실행 → game/cast/NN.png 저장.
(학생용 게임엔 '완성된 이미지'만 들어가고 키는 절대 안 들어간다.)
실행: PIKA_API_KEY=... python game/gen_cast.py
"""
import json
import os
import time
from pathlib import Path

import requests

BASE = "https://api.dev.pika.art"
MODEL = "bytedance/seedream-5.0-pro/text-to-image"
HERE = Path(__file__).resolve().parent
OUT = HERE / "cast"
OK = {"completed", "succeeded", "success", "done", "finished"}
FAIL = {"failed", "error", "canceled", "cancelled", "expired"}

# 모든 캐릭터에 공통으로 붙이는 '통일된 화풍' — 귀여운 3D 만화 캐릭터, 정면 상반신, 단색 배경.
STYLE = ("cute 3D cartoon character, Pixar-style render, chibi proportions with a big head, "
         "friendly and wholesome, front-facing upper-body portrait, centered, soft studio lighting, "
         "clean flat pastel background, smooth shading, high quality, no text, no watermark")


def _find_url(d):
    if isinstance(d, str) and d.startswith("http"):
        return d
    if isinstance(d, dict):
        for k in ("url", "image_url", "download_url", "output_url"):
            if isinstance(d.get(k), str) and d[k].startswith("http"):
                return d[k]
        d = list(d.values())
    if isinstance(d, list):
        for it in d:
            if (u := _find_url(it)):
                return u
    return None


def generate(sess, prompt, dest):
    body = {"prompt": f"{prompt}, {STYLE}", "aspect_ratio": "1:1"}
    r = sess.post(f"{BASE}/v1/media/{MODEL}", json=body, timeout=60)
    r.raise_for_status()
    jid = (r.json().get("id") or r.json().get("request_id") or r.json().get("job_id"))
    deadline = time.time() + 15 * 60
    while time.time() < deadline:
        jr = sess.get(f"{BASE}/v1/media/jobs/{jid}", timeout=60)
        jr.raise_for_status()
        data = jr.json()
        st = str(data.get("status", "")).lower()
        if st in OK:
            url = _find_url(data) or f"{BASE}/v1/media/jobs/{jid}/content"
            img = sess.get(url, timeout=300)
            img.raise_for_status()
            dest.write_bytes(img.content)
            return
        if st in FAIL:
            raise RuntimeError(f"생성 실패({st}): {data}")
        time.sleep(8)
    raise TimeoutError("시간 초과")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    prompts = json.loads((HERE / "prompts.json").read_text(encoding="utf-8"))
    sess = requests.Session()
    sess.headers.update({"X-API-Key": os.environ["PIKA_API_KEY"]})
    for i, p in enumerate(prompts):
        dest = OUT / f"{i:02d}_{p['gender']}.png"
        if dest.exists():
            print(f"[skip] {dest.name}")
            continue
        print(f"[gen ] {dest.name}: {p['desc'][:50]}")
        try:
            generate(sess, p["desc"], dest)
        except Exception as e:  # noqa: BLE001
            print(f"   [실패-건너뜀] {e}")
    print("완료:", len(list(OUT.glob('*.png'))), "장")


if __name__ == "__main__":
    main()
