"""장면 하나를 Pika API 로 영상(+음성) 클립으로 만든다.

프롬프트 형식은 Pika H3 Flex 공식 가이드(docs/prompt-guidance.md)의 T2VA 구조를 따른다:
  integrated_multimodal_description / overall_soundscape / non_diegetic_music
내레이션은 화면 밖 보이스오버 대사 태그 <d>[언어] ...</d> 로 넣어 영상과 함께 생성한다.
"""

import subprocess
import time
from pathlib import Path

import requests

TERMINAL_OK = {"completed", "succeeded", "success", "done"}
TERMINAL_FAIL = {"failed", "error", "canceled", "cancelled", "expired"}


def build_prompt(scene: dict, cfg: dict) -> str:
    ch = cfg["channel"]
    narration = scene["narration"].strip()
    voiceover = (
        f"Throughout the shot, a narrator says in an off-screen voiceover, {ch['narrator_voice']} (S1), "
        f"<d>[{ch['language']}] {narration}</d> No one on screen speaks; any visible lips remain closed."
    )
    return (
        "integrated_multimodal_description:\n"
        f"[Shot 1] {scene['shot'].strip()} Style: {ch['visual_style'].strip().rstrip('.')}. {voiceover}\n\n"
        "overall_soundscape:\n"
        f"{scene['soundscape'].strip()}\n\n"
        "non_diegetic_music:\n"
        f"{scene['music'].strip() or 'N/A'}\n"
    )


def aspect_for(cfg: dict) -> str:
    return "9:16" if cfg["video"]["format"] == "shorts" else "16:9"


class PikaClient:
    def __init__(self, cfg: dict, api_key: str):
        self.cfg = cfg["pika"]
        self.aspect = aspect_for(cfg)
        self.session = requests.Session()
        self.session.headers.update({"X-API-Key": api_key})
        self.base = self.cfg["base_url"].rstrip("/")

    def submit(self, prompt: str, duration: int) -> str:
        body = {
            "prompt": prompt,
            "duration": duration,
            "aspect_ratio": self.aspect,
            "resolution": self.cfg["resolution"],
            **(self.cfg.get("extra_body") or {}),
        }
        r = self.session.post(f"{self.base}/v1/media/{self.cfg['model_path']}", json=body, timeout=60)
        if r.status_code >= 400:
            raise RuntimeError(f"Pika 요청 실패 {r.status_code}: {r.text[:500]}")
        data = r.json()
        job_id = data.get("id") or data.get("request_id") or data.get("job_id")
        if not job_id:
            raise RuntimeError(f"Pika 응답에 작업 ID가 없습니다: {data}")
        return job_id

    def wait(self, job_id: str) -> dict:
        deadline = time.time() + self.cfg["timeout_minutes"] * 60
        while time.time() < deadline:
            r = self.session.get(f"{self.base}/v1/media/jobs/{job_id}", timeout=60)
            r.raise_for_status()
            data = r.json()
            status = str(data.get("status", "")).lower()
            if status in TERMINAL_OK:
                return data
            if status in TERMINAL_FAIL:
                raise RuntimeError(f"Pika 생성 실패 ({status}): {data}")
            time.sleep(self.cfg["poll_interval_seconds"])
        raise TimeoutError(f"Pika 작업 {job_id} 이(가) {self.cfg['timeout_minutes']}분 안에 끝나지 않았습니다.")

    def download(self, job_id: str, dest: Path) -> None:
        r = self.session.get(f"{self.base}/v1/media/jobs/{job_id}/content", timeout=300, stream=True)
        r.raise_for_status()
        if "application/json" in r.headers.get("content-type", ""):
            # 영상 대신 다운로드 URL 을 돌려주는 경우
            data = r.json()
            url = _find_url(data)
            if not url:
                raise RuntimeError(f"결과에서 영상 URL을 찾지 못했습니다: {data}")
            r = requests.get(url, timeout=300, stream=True)
            r.raise_for_status()
        tmp = dest.with_suffix(".part")
        with open(tmp, "wb") as f:
            for chunk in r.iter_content(1 << 20):
                f.write(chunk)
        tmp.replace(dest)

    def render(self, scene: dict, cfg: dict, dest: Path) -> None:
        job_id = self.submit(build_prompt(scene, cfg), scene["duration"])
        print(f"    작업 {job_id} 생성 중...")
        self.wait(job_id)
        self.download(job_id, dest)


def _find_url(data):
    if isinstance(data, str) and data.startswith("http"):
        return data
    if isinstance(data, dict):
        for key in ("url", "video_url", "download_url"):
            if isinstance(data.get(key), str):
                return data[key]
        data = list(data.values())
    if isinstance(data, list):
        for item in data:
            if found := _find_url(item):
                return found
    return None


class MockClient:
    """API 비용 없이 파이프라인을 시험하는 가짜 엔진. 색 화면 + 효과음 클립을 만든다."""

    def __init__(self, cfg: dict):
        w, h = (720, 1280) if cfg["video"]["format"] == "shorts" else (1280, 720)
        self.size = f"{w}x{h}"

    def render(self, scene: dict, cfg: dict, dest: Path) -> None:
        d = scene["duration"]
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error",
             "-f", "lavfi", "-i", f"testsrc2=size={self.size}:rate=24:duration={d}",
             "-f", "lavfi", "-i", f"sine=frequency=220:duration={d}",
             "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac", "-shortest", str(dest)],
            check=True,
        )
