"""Microsoft Edge 무료 TTS(edge-tts)로 내레이션 생성. 키·요금 없음.

단어별 타이밍(WordBoundary)을 받아 자막 싱크에 사용한다.
※ 비공식 무료 서비스라 아주 가끔 네트워크 문제로 실패할 수 있다(재시도로 대응).
"""

import asyncio
import re
from pathlib import Path

from .base import chunk_narration, estimate_seconds


def _norm(tok: str) -> str:
    """발화되는 알맹이만 남긴다(문장부호·em대시 등 제거). 빈 문자열이면 '발화 안 되는 토큰'."""
    return re.sub(r"[^0-9a-z]+", "", tok.lower())


class EdgeEngine:
    name = "edge"

    def __init__(self, cfg: dict):
        self.voice_name = cfg.get("engines", {}).get("edge_voice", "en-US-ChristopherNeural")

    def voice(self, scene: dict, out: Path) -> dict:
        import edge_tts

        text = scene["narration"].strip()
        words: list[tuple[str, float, float]] = []

        async def run() -> None:
            comm = edge_tts.Communicate(text, self.voice_name)
            with open(out, "wb") as f:
                async for chunk in comm.stream():
                    if chunk["type"] == "audio":
                        f.write(chunk["data"])
                    elif chunk["type"] == "WordBoundary":
                        start = chunk["offset"] / 1e7
                        words.append((chunk["text"], start, start + chunk["duration"] / 1e7))

        last_err = None
        for _ in range(3):
            try:
                words.clear()
                asyncio.run(run())
                if out.exists() and out.stat().st_size > 0:
                    return _timing(scene, words)
            except Exception as e:  # noqa: BLE001
                last_err = e
        raise RuntimeError(f"edge-tts 실패: {last_err}")


def _timing(scene: dict, words: list) -> dict:
    """자막 조각 타이밍을 '실제 발화 구간'에 글자 수 비례로 배분한다.

    단어 수 매칭은 edge-tts가 숫자("1405"→"fourteen oh five")·약어 등을 여러 단어로 읽어
    조각 단어 수와 어긋나며 뒤로 갈수록 밀린다. 비례 배분은 그런 영향이 없어 안 밀린다.
    """
    chunks = chunk_narration(scene["narration"])
    highlight = scene.get("highlight", [])
    if words:
        t0, t1 = words[0][1], words[-1][2]          # 첫 단어 시작 ~ 마지막 단어 끝
    else:
        t0, t1 = 0.0, estimate_seconds(scene["narration"])
    span = max(t1 - t0, 0.5)
    weights = [max(1, len(_norm(c.replace(" ", "")))) for c in chunks]  # 조각별 발화 글자 수
    tot = sum(weights)
    entries, acc = [], 0
    for c, wgt in zip(chunks, weights):
        start = t0 + span * acc / tot
        acc += wgt
        end = t0 + span * acc / tot
        entries.append({"text": c, "start": round(start, 2), "end": round(end, 2),
                        "highlight": [w for w in highlight if w in c]})
    return {"duration": round(t1 + 0.3, 2), "chunks": entries}
