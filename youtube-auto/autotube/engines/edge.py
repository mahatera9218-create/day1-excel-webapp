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


# 캐릭터 보이스 팔레트(무료 edge-tts). 작가가 장면의 "voice" 에 이 별칭을 넣으면 그 목소리로 읽는다.
# 억양을 섞어 인물이 서로 다르게 들리게 했다. 'narrator' 는 채널 기본 목소리로 해석.
VOICE_ALIASES = {
    "m1": "en-GB-RyanNeural",      # 영국 남성
    "m2": "en-US-EricNeural",      # 미국 남성(묵직)
    "m3": "en-AU-WilliamNeural",   # 호주 남성
    "f1": "en-US-JennyNeural",     # 미국 여성
    "f2": "en-GB-SoniaNeural",     # 영국 여성
    "f3": "en-US-AriaNeural",      # 미국 여성(다른 톤)
}


class EdgeEngine:
    name = "edge"

    def __init__(self, cfg: dict):
        self.voice_name = cfg.get("engines", {}).get("edge_voice", "en-US-ChristopherNeural")

    def _resolve(self, scene: dict) -> str:
        """장면의 voice 지정을 실제 edge 목소리 이름으로. 없거나 narrator 면 채널 기본."""
        v = (scene.get("voice") or "").strip()
        if not v or v == "narrator":
            return self.voice_name
        if v in VOICE_ALIASES:
            return VOICE_ALIASES[v]
        if "Neural" in v:  # 원시 edge 목소리 이름을 직접 넣은 경우
            return v
        return self.voice_name

    def voice(self, scene: dict, out: Path) -> dict:
        import edge_tts

        text = scene["narration"].strip()
        voice_name = self._resolve(scene)
        words: list[tuple[str, float, float]] = []

        async def run() -> None:
            comm = edge_tts.Communicate(text, voice_name)
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
                    self.last_words = list(words)   # 디버그/검증용 원시 단어 타임스탬프
                    return _timing(scene, words)
            except Exception as e:  # noqa: BLE001
                last_err = e
        raise RuntimeError(f"edge-tts 실패: {last_err}")


def _spoken_weight(chunk: str) -> int:
    """조각의 '발화 길이' 추정치. 숫자는 글자보다 길게 읽히므로(5→five, 0→oh) 자리당 가중치를 더 준다."""
    return max(1, sum(3 if ch.isdigit() else 1 for ch in _norm(chunk)))


def _timing(scene: dict, words: list) -> dict:
    """자막 줄을 '실제 단어 타임스탬프'로 만든다 → 오디오와 그대로 동기.

    edge-tts 가 주는 단어별 (텍스트, 시작, 끝) 을 그대로 묶어 줄을 만든다. 각 줄의 시작·끝이
    '그 단어들을 실제로 말하는 시각'이라 밀리지 않는다(숫자를 여러 단어로 읽어도 그 단어들의
    실제 시각을 쓰므로 어긋나지 않음). 단어 경계가 없을 때만 글자수 비례로 폴백한다.
    """
    highlight = scene.get("highlight", [])
    if not words:
        return _by_proportion(chunk_narration(scene["narration"]), highlight,
                              0.0, estimate_seconds(scene["narration"]))
    chunks = []
    cur, start, end = [], None, None
    for text, s, e in words:
        if start is None:
            start = s
        cur.append(text)
        end = e
        line = " ".join(cur)
        if len(line) >= 42 or text[-1:] in ".!?,;:":   # 길이 or 문장부호에서 줄 끊기
            chunks.append(_line(line, start, end, highlight))
            cur, start, end = [], None, None
    if cur:
        chunks.append(_line(" ".join(cur), start, end, highlight))
    return {"duration": round(words[-1][2] + 0.3, 2), "chunks": chunks}


def _line(text: str, start: float, end: float, highlight: list) -> dict:
    return {"text": text, "start": round(start, 2), "end": round(max(end, start + 0.2), 2),
            "highlight": [h for h in highlight if h.lower() in text.lower()]}


def _by_proportion(chunks: list, highlight: list, t0: float, t1: float) -> dict:
    """폴백: 단어 경계가 없을 때만 글자수 비례."""
    span = max(t1 - t0, 0.5)
    weights = [_spoken_weight(c) for c in chunks]
    tot = sum(weights)
    out, acc = [], 0
    for c, wgt in zip(chunks, weights):
        a = t0 + span * acc / tot
        acc += wgt
        b = t0 + span * acc / tot
        out.append({"text": c, "start": round(a, 2), "end": round(b, 2),
                    "highlight": [w for w in highlight if w in c]})
    return {"duration": round(t1 + 0.3, 2), "chunks": out}
