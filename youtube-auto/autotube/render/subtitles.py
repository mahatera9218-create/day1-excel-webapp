"""말 타이밍에 맞춰 ASS 자막을 만든다. 대본의 highlight 단어는 다른 색으로 강조한다."""

from pathlib import Path


def _ass_color(rrggbb: str) -> str:
    rrggbb = rrggbb.lstrip("#")
    r, g, b = rrggbb[0:2], rrggbb[2:4], rrggbb[4:6]
    return f"&H00{b}{g}{r}".upper()


def _ts(seconds: float) -> str:
    cs = int(round(seconds * 100))
    h, cs = divmod(cs, 360000)
    m, cs = divmod(cs, 6000)
    s, cs = divmod(cs, 100)
    return f"{h}:{m:02}:{s:02}.{cs:02}"


def _apply_highlight(text: str, words: list[str], hi: str, base: str) -> str:
    for w in sorted(words or [], key=len, reverse=True):
        w = w.strip()
        if w and w in text:
            text = text.replace(w, f"{{\\c{hi}}}{w}{{\\c{base}}}", 1)
    return text


def build_ass(entries: list[dict], cfg: dict, size: tuple[int, int], path: Path) -> None:
    """entries: [{start, end, text, highlight:[...]}] — start/end 는 전체 영상 기준 초."""
    w, h = size
    base = _ass_color(cfg.get("primary_color", "FFFFFF"))
    hi = _ass_color(cfg.get("highlight_color", "32C8FF"))
    font = cfg.get("font", "Noto Sans KR")
    size_pt = cfg.get("font_size", 44)
    outline = cfg.get("outline", 4)
    margin = cfg.get("margin_v", 90)

    header = f"""[Script Info]
ScriptType: v4.00+
PlayResX: {w}
PlayResY: {h}
WrapStyle: 2
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, OutlineColour, BackColour, Bold, Outline, Shadow, Alignment, MarginL, MarginR, MarginV
Style: Main,{font},{size_pt},{base},&H00000000,&H00000000,1,{outline},0,2,80,80,{margin}

[Events]
Format: Layer, Start, End, Style, Text
"""
    lines = []
    for e in entries:
        text = _apply_highlight(e["text"].strip(), e.get("highlight"), hi, base)
        lines.append(f"Dialogue: 0,{_ts(e['start'])},{_ts(e['end'])},Main,{text}")
    path.write_text(header + "\n".join(lines) + "\n", encoding="utf-8")
