"""기획: 소재 하나를 제목·설명·태그 + 장면 목록(plan.json)으로 만든다.

실제 운영에서는 Claude(월구독)에게 '다음 편 써줘' 하면 이 형식으로 plan.json 을
채워 준다. --mock 은 키 없이 흐름을 시험하기 위한 가짜 대본이다.
"""

import json
from pathlib import Path


_BEATS_KO = [
    ("한 선비가 깊은 산길을 홀로 걷고 있었습니다.", ["깊은 산길"], "a scholar walking alone on a misty mountain path at dusk", "kenburns_in"),
    ("날이 저물자, 멀리 외딴 기와집에서 불빛이 새어 나왔습니다.", ["외딴 기와집"], "a lone tiled house glowing with lantern light in the dark forest", "kenburns_pan"),
    ("문을 열어준 여인은 눈이 부시도록 아름다웠습니다.", ["아름다웠습니다"], "a mysterious beautiful woman opening a wooden gate, warm light behind her", "video"),
    ("하지만 선비는 그녀의 그림자가 아홉 갈래로 갈라진 것을 보지 못했습니다.", ["아홉 갈래"], "a woman's shadow splitting into nine fox tails on the floor, candlelight", "kenburns_in"),
    ("그날 이후, 마을에서는 선비를 다시 볼 수 없었습니다.", ["다시 볼 수 없었습니다"], "an empty mountain village at dawn, cold fog, no people", "kenburns_pan"),
]
_BEATS_EN = [
    ("Long ago, in a village at the edge of the forest, an old story began.", ["old story"], "a quiet old village at the edge of a vast misty forest at dusk", "kenburns_in"),
    ("Every night, something was heard beyond the treeline.", ["every night"], "dark dense forest at night, faint glow between the trees", "kenburns_pan"),
    ("A lone traveler decided to find out what it was.", ["lone traveler"], "a cloaked traveler walking toward the dark woods, lantern in hand", "video"),
    ("What they found would be told for a hundred years.", ["hundred years"], "a mysterious glowing figure deep in the forest, mist and moonlight", "kenburns_in"),
    ("And to this day, the villagers never go there after dark.", ["never go there"], "empty forest path at dawn, cold fog, no people", "kenburns_pan"),
]


def mock_plan(cfg: dict, topic: str) -> dict:
    style = cfg["visual_style"].strip()
    korean = cfg.get("language") == "Korean"
    beats = _BEATS_KO if korean else _BEATS_EN
    sfx = "wind, distant night sounds"
    scenes = [{"narration": n, "highlight": h, "image_prompt": f"{p}, {style}",
               "motion": m, "sfx": sfx} for n, h, p, m in beats]
    if korean:
        desc, tags = "옛이야기를 차분하게 들려드립니다.", ["야담", "전설", "옛이야기", "한국설화", "괴담"]
    else:
        desc = "A folk tale retold. Relax and listen."
        tags = ["folklore", "mythology", "legends", "folk tales", "storytelling", "bedtime story"]
    return {
        "topic": topic,
        "title": f"{cfg.get('title_prefix', '')} {topic}".strip(),
        "description": f"{topic}\n\n{desc}",
        "tags": tags,
        "scenes": scenes,
    }


def write_script_md(plan: dict, path: Path) -> None:
    """사람이 읽고 고치기 쉬운 형태. 검토용."""
    lines = [f"# {plan['title']}\n", f"> 소재: {plan['topic']}\n",
             f"**설명**\n\n{plan['description']}\n", f"**태그**: {', '.join(plan['tags'])}\n", "---\n"]
    for i, s in enumerate(plan["scenes"], 1):
        lines.append(f"### 장면 {i}  ·  {s['motion']}")
        lines.append(f"- 내레이션: {s['narration']}")
        lines.append(f"- 강조: {', '.join(s.get('highlight', [])) or '-'}")
        lines.append(f"- 그림: {s['image_prompt']}\n")
    path.write_text("\n".join(lines), encoding="utf-8")
