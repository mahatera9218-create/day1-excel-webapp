"""Pika API 로 그림(이미지)과 움직이는 영상(image-to-video)을 만든다.

주의: dev.pika.art 의 정확한 요청 형식은 모델마다 다릅니다. 첫 real 실행에서
400/422 가 나면 channel.yaml 의 engines.image_model / video_model 과
engines.*_extra 를 에러 메시지에 맞춰 조정하세요.
"""

import base64
import time
from pathlib import Path

import requests

from ..render.util import frame_size
from .base import estimate_seconds, even_timing

OK = {"completed", "succeeded", "success", "done", "finished"}
FAIL = {"failed", "error", "canceled", "cancelled", "expired"}


def _aspect(_cfg) -> str:
    return "16:9"


class PikaEngine:
    name = "pika"

    def __init__(self, cfg: dict, api_key: str):
        self.e = cfg["engines"]
        self.base = "https://api.dev.pika.art"
        self.s = requests.Session()
        self.s.headers.update({"X-API-Key": api_key})

    def _job(self, model_path: str, body: dict) -> dict:
        r = self.s.post(f"{self.base}/v1/media/{model_path}", json=body, timeout=60)
        if r.status_code >= 400:
            raise RuntimeError(f"Pika 요청 실패 {r.status_code} ({model_path}): {r.text[:400]}")
        job_id = _dig(r.json(), ("id", "request_id", "job_id"))
        if not job_id:
            raise RuntimeError(f"Pika 응답에 작업 ID 없음: {r.json()}")
        deadline = time.time() + 20 * 60
        while time.time() < deadline:
            jr = self.s.get(f"{self.base}/v1/media/jobs/{job_id}", timeout=60)
            jr.raise_for_status()
            data = jr.json()
            status = str(data.get("status", "")).lower()
            if status in OK:
                return {"job_id": job_id, "data": data}
            if status in FAIL:
                raise RuntimeError(f"Pika 생성 실패 ({status}): {data}")
            time.sleep(10)
        raise TimeoutError(f"Pika 작업 {job_id} 시간 초과")

    def _download(self, job_id: str, data: dict, dest: Path) -> None:
        url = _find_url(data) or f"{self.base}/v1/media/jobs/{job_id}/content"
        r = self.s.get(url, timeout=300, stream=True)
        r.raise_for_status()
        if "application/json" in r.headers.get("content-type", ""):
            url = _find_url(r.json())
            r = requests.get(url, timeout=300, stream=True)
            r.raise_for_status()
        with open(dest, "wb") as f:
            for chunk in r.iter_content(1 << 20):
                f.write(chunk)

    # ElevenLabs 가 목소리를 담당하므로 Pika 엔진에선 음성을 만들지 않는다 (무음 폴백).
    def voice(self, scene: dict, out: Path):
        raise NotImplementedError("voice 는 ElevenLabs 엔진이 담당합니다.")

    def image(self, scene: dict, out: Path) -> None:
        body = {
            "prompt": f"{scene['image_prompt']} {scene.get('_style', '')}".strip(),
            "aspect_ratio": _aspect(self.e),
            **(self.e.get("image_extra") or {}),
        }
        job = self._job(self.e["image_model"], body)
        self._download(job["job_id"], job["data"], out)

    def video(self, scene: dict, image: Path, out: Path, duration: float) -> None:
        with open(image, "rb") as f:
            img_b64 = base64.b64encode(f.read()).decode()
        body = {
            "prompt": scene.get("video_prompt") or scene["image_prompt"],
            "image": f"data:image/png;base64,{img_b64}",
            "duration": max(5, min(15, round(duration))),
            "aspect_ratio": _aspect(self.e),
            "resolution": self.e.get("video_resolution", "480p"),
            **(self.e.get("video_extra") or {}),
        }
        job = self._job(self.e["video_model"], body)
        self._download(job["job_id"], job["data"], out)


def _dig(data: dict, keys):
    for k in keys:
        if data.get(k):
            return data[k]
    return None


def _find_url(data):
    if isinstance(data, str) and data.startswith("http"):
        return data
    if isinstance(data, dict):
        for key in ("url", "video_url", "image_url", "download_url", "output_url"):
            if isinstance(data.get(key), str) and data[key].startswith("http"):
                return data[key]
        data = list(data.values())
    if isinstance(data, list):
        for item in data:
            if found := _find_url(item):
                return found
    return None
