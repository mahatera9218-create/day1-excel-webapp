"""엔진 공통 도우미: 내레이션을 자막 덩어리로 나누고, 타이밍을 배분한다."""

import re


def chunk_narration(text: str, max_chars: int = 22) -> list[str]:
    """내레이션을 화면에 한 번에 띄울 짧은 덩어리로 나눈다."""
    pieces = [p.strip() for p in re.split(r"(?<=[.!?。…,·])\s+", text.strip()) if p.strip()]
    out: list[str] = []
    for piece in pieces:
        if len(piece) <= max_chars:
            out.append(piece)
            continue
        line = ""
        for word in piece.split():
            if line and len(line) + 1 + len(word) > max_chars:
                out.append(line)
                line = word
            else:
                line = f"{line} {word}".strip()
        if line:
            out.append(line)
    return out or [text.strip()]


def estimate_seconds(text: str) -> float:
    """느린 한국어 내레이션 기준 대략적인 길이(초)."""
    chars = len(re.sub(r"\s", "", text))
    return round(max(2.5, chars / 4.3 + 0.6), 2)


def even_timing(scene: dict, duration: float) -> dict:
    """장면 길이에 맞춰 자막 덩어리를 글자 수 비율로 배분한다 (mock / 폴백용)."""
    chunks = chunk_narration(scene["narration"])
    total = sum(len(c) for c in chunks) or 1
    highlight = scene.get("highlight", [])
    entries, t, span = [], 0.3, max(duration - 0.6, 1.0)
    for c in chunks:
        length = span * len(c) / total
        entries.append({"text": c, "start": round(t, 2), "end": round(t + length, 2),
                        "highlight": [w for w in highlight if w in c]})
        t += length
    return {"duration": duration, "chunks": entries}
