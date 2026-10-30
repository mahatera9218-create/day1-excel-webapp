"""Claude 로 영상 기획안(제목·설명·태그·장면별 내레이션과 연출)을 만든다."""

import json

import anthropic

PLAN_SCHEMA = {
    "type": "object",
    "properties": {
        "title": {"type": "string", "description": "유튜브 제목. 60자 이내, 클릭을 부르되 낚시는 금지"},
        "description": {"type": "string", "description": "영상 설명란 본문 (3~6줄)"},
        "tags": {"type": "array", "items": {"type": "string"}},
        "scenes": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "duration": {"type": "integer", "description": "장면 길이(초), 5~15"},
                    "narration": {"type": "string", "description": "이 장면의 내레이션 원문"},
                    "shot": {
                        "type": "string",
                        "description": "English. What is on screen: subjects, positions, actions in order, camera move, ending state.",
                    },
                    "soundscape": {
                        "type": "string",
                        "description": "English, 1-3 sentences of ambience and physical sounds. No dialogue, no music.",
                    },
                    "music": {"type": "string", "description": "English, 1-2 sentences: instrumentation, tempo, volume."},
                },
                "required": ["duration", "narration", "shot", "soundscape", "music"],
                "additionalProperties": False,
            },
        },
    },
    "required": ["title", "description", "tags", "scenes"],
    "additionalProperties": False,
}


SYSTEM = """You are the head writer of a YouTube channel. You plan one video at a time as a sequence of short AI-generated shots.

Channel concept:
{concept}

Rules:
- Narration language: {language}. Everything else (shot, soundscape, music) in English.
- Total length about {target_seconds} seconds, {min_scenes}-{max_scenes} scenes, each scene 5-15 seconds.
- Narration must fit its scene: about 5 {language} syllables per second at most, so a 10-second scene carries at most ~50 syllables. Leave half a second of breathing room.
- Scene 1 is the hook: a striking question or fact within the first 2 seconds.
- The last scene closes the story and makes viewers want the next video.
- Stay factual. If something is uncertain or disputed, say so in the narration. Never invent statistics, quotes or real people's words.
- Each shot is a single, self-contained, visually concrete moment. State how many subjects there are, where they are, what moves, the camera move (direction and speed), and how the shot ends.
- No real people, brands, logos, or copyrighted characters on screen. No on-screen text.
- Keep the same visual world across scenes so the cuts feel like one film.
- Write the title and description in {language}. Add 8-15 relevant tags."""


def write_plan(cfg: dict, topic: str) -> dict:
    ch, video, cl = cfg["channel"], cfg["video"], cfg["claude"]
    client = anthropic.Anthropic()
    system = SYSTEM.format(
        concept=ch["concept"].strip(),
        language=ch["language"],
        target_seconds=video["target_seconds"],
        min_scenes=video["min_scenes"],
        max_scenes=video["max_scenes"],
    )
    response = client.beta.messages.create(
        model=cl["model"],
        max_tokens=16000,
        system=system,
        messages=[{"role": "user", "content": f"Plan the next video. Topic: {topic}"}],
        output_config={"effort": cl.get("effort", "high"), "format": {"type": "json_schema", "schema": PLAN_SCHEMA}},
        betas=["server-side-fallback-2026-07-01"],
        fallbacks="default",
    )
    if response.stop_reason == "refusal":
        raise SystemExit(f"[오류] Claude 가 이 주제의 대본 작성을 거절했습니다. 주제를 바꿔주세요: {topic}")
    if response.stop_reason == "max_tokens":
        raise SystemExit("[오류] 대본이 너무 길어 잘렸습니다. target_seconds 나 max_scenes 를 줄여주세요.")

    text = next(b.text for b in response.content if b.type == "text")
    plan = json.loads(text)
    for scene in plan["scenes"]:
        scene["duration"] = max(5, min(15, int(scene["duration"])))
    plan["topic"] = topic
    return plan
