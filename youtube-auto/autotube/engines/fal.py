"""fal.ai 로 이미지를 생성한다 (기본 Flux). Pika/Seedream 대체.

channel.yaml:
  engines:
    image: fal
    fal_image_model: fal-ai/flux/dev     # (선택) fal-ai/flux/schnell(초저가) · fal-ai/flux-pro/v1.1(최고)
    fal_image_size: {width: 1344, height: 768}   # (선택) 또는 "landscape_16_9"
    fal_image_extra: {}                  # (선택) 모델별 추가 파라미터

키: 환경변수 FAL_KEY (fal.ai 대시보드의 API Key). 헤더 Authorization: Key <FAL_KEY>.
"""

from pathlib import Path

import requests


class FalEngine:
    name = "fal"

    def __init__(self, cfg: dict, api_key: str):
        self.e = cfg["engines"]
        self.key = api_key
        self.base = "https://fal.run"
        self.model = self.e.get("fal_image_model", "fal-ai/flux/dev")
        self.size = self.e.get("fal_image_size", {"width": 1344, "height": 768})
        self.extra = self.e.get("fal_image_extra") or {}
        self.s = requests.Session()
        self.s.headers.update({"Authorization": f"Key {api_key}"})

    # Pika 엔진과 동일한 인터페이스. 모션(video)은 담당하지 않는다(스틸 폴백).
    def voice(self, scene, out):
        raise NotImplementedError("voice 는 edge/ElevenLabs 담당")

    def image(self, scene: dict, out: Path) -> None:
        prompt = f"{scene['image_prompt']} {scene.get('_style', '')}".strip()
        body = {
            "prompt": prompt,
            "image_size": self.size,
            "num_images": 1,
            "enable_safety_checker": False,
            "output_format": "png",
            **self.extra,
        }
        r = self.s.post(f"{self.base}/{self.model}", json=body, timeout=180)
        if r.status_code >= 400:
            raise RuntimeError(f"fal 이미지 생성 실패 {r.status_code} ({self.model}): {r.text[:400]}")
        data = r.json()
        imgs = data.get("images") or []
        if not imgs or not imgs[0].get("url"):
            raise RuntimeError(f"fal 응답에 이미지 URL 없음: {str(data)[:400]}")
        ir = requests.get(imgs[0]["url"], timeout=120)
        ir.raise_for_status()
        Path(out).write_bytes(ir.content)

    def video(self, scene, image, out, duration):
        raise RuntimeError("fal 엔진은 모션(image-to-video)을 안 합니다 — 스틸로 폴백.")
