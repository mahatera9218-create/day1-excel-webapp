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
    chunks = chunk_narration(scene["narration"])
    highlight = scene.get("highlight", [])
    total = words[-1][2] if words else estimate_seconds(scene["narration"])
    # edge-tts가 실제로 발화 이벤트를 준 단어만 (시작, 끝) 으로. 부호 전용 토큰은 edge도 안 주고
    # 아래 조각 토큰 셈에서도 빼므로, 양쪽 개수가 맞아 싱크가 밀리지 않는다.
    spoken = [(s, e) for (t, s, e) in words if _norm(t)]
    entries, wi = [], 0
    for c in chunks:
        ntok = sum(1 for t in c.split() if _norm(t))  # 발화되는 단어 수만
        seg = spoken[wi:wi + ntok]
        wi += ntok
        if seg:
            start, end = seg[0][0], seg[-1][1]
        else:
            start = entries[-1]["end"] if entries else 0.0
            end = start + 1.0
        entries.append({"text": c, "start": round(start, 2), "end": round(end, 2),
                        "highlight": [w for w in highlight if w in c]})
    return {"duration": round(total + 0.3, 2), "chunks": entries}
