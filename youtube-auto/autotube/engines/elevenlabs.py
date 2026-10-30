"""ElevenLabs 로 한국어 내레이션을 만들고, 글자별 타이밍으로 자막 시점을 맞춘다."""

import base64
from pathlib import Path

import requests

from .base import chunk_narration


class ElevenLabsEngine:
    name = "elevenlabs"

    def __init__(self, cfg: dict, api_key: str):
        self.voice_id = cfg.get("voice_id") or ""
        self.model = cfg.get("engines", {}).get("tts_model", "eleven_multilingual_v2")
        self.s = requests.Session()
        self.s.headers.update({"xi-api-key": api_key})
        if not self.voice_id:
            raise SystemExit("[오류] channel.yaml 의 voice_id 가 비어 있습니다. ElevenLabs 목소리를 고르세요.")

    def voice(self, scene: dict, out: Path) -> dict:
        url = f"https://api.elevenlabs.io/v1/text-to-speech/{self.voice_id}/with-timestamps"
        r = self.s.post(url, json={"text": scene["narration"], "model_id": self.model,
                                   "output_format": "mp3_44100_128"}, timeout=120)
        if r.status_code >= 400:
            raise RuntimeError(f"ElevenLabs 실패 {r.status_code}: {r.text[:300]}")
        data = r.json()
        out.write_bytes(base64.b64decode(data["audio_base64"]))
        return _timing_from_alignment(scene, data.get("alignment") or data.get("normalized_alignment"))


def _timing_from_alignment(scene: dict, align: dict | None) -> dict:
    highlight = scene.get("highlight", [])
    chunks = chunk_narration(scene["narration"])
    if not align:
        from .base import estimate_seconds, even_timing
        return even_timing(scene, estimate_seconds(scene["narration"]))
    chars = align["characters"]
    starts = align["character_start_times_seconds"]
    ends = align["character_end_times_seconds"]
    full = "".join(chars)
    entries, cursor = [], 0
    for c in chunks:
        idx = full.find(c, cursor)
        if idx < 0:
            idx = cursor
        end_idx = min(idx + len(c), len(chars)) - 1
        entries.append({
            "text": c,
            "start": round(starts[idx], 2),
            "end": round(ends[max(end_idx, idx)], 2),
            "highlight": [w for w in highlight if w in c],
        })
        cursor = idx + len(c)
    return {"duration": round(ends[-1], 2), "chunks": entries}
