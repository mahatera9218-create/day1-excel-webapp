# Drafting SOP — `world` channel (world folklore, English)

This is the brief the scheduled drafting session follows. Goal: research and draft the
next few episodes as `plan.json` files, ready for the human to review. **Never approve.**

## What to produce each run

- Draft **4 episodes** (enough for one week of 3 uploads + buffer).
- Spread them across **different continents** (don't do four from one region).
- Pick topics from `channels/world/topics.txt` that have no episode yet, or research a
  fresh, lesser-known tale. Prefer tales that are **public-domain folklore**, not modern
  copyrighted characters.

## Steps for each episode

1. **Research first.** Use web search to confirm the tale's origin, the culture it belongs
   to, names, and the commonly told plot. Note 2-3 sources. If sources conflict or the tale
   is sacred/sensitive, choose a respectful mainstream version and say so in the description.
2. Scaffold: `python -m autotube new world --topic "<Tale name (Country)>"`
3. Overwrite the generated `plan.json` with the real episode (schema below).
4. Leave `status.json` as `approved: false`.
5. `git add -A && git commit` then push. Do **not** render or upload.

## plan.json schema and rules

```json
{
  "topic": "The Fox Spirit Bride (Korea)",
  "title": "The Fox Spirit Who Married a Scholar | Korean Folklore",
  "description": "2-4 lines. End with a one-line source note.",
  "tags": ["folklore","korean mythology","gumiho","legends","storytelling", "..."],
  "scenes": [ { "narration": "...", "highlight": ["..."], "image_prompt": "...", "motion": "kenburns_in", "sfx": "..." } ]
}
```

- **Length:** target ~18 minutes. At ~2.3 English words/second, that's ~2,500 words total.
  Use **24-45 scenes**. Each scene's narration ≈ 40-90 words.
- **Scene 1 is the hook:** a striking question or image in the first 5 seconds.
- **Tell it as an immersive story, not a summary.** Build a clear arc: setup → rising
  tension → turning point → resolution. Use sensory, concrete detail (sound, light,
  weather), vary sentence rhythm, and end scenes on small cliff-hangers that pull the
  viewer forward. Avoid encyclopedic "and then, and then" narration.
- **Use character dialogue.** Weave short quoted lines into the narration to bring scenes
  alive — e.g. `Nyame's laughter shook the clouds. "Greater kings have tried," he said.`
  One narrator reads everything, so attribute each line ("he said", "the woman whispered").
  Keep quotes natural and faithful to the tale; don't fabricate specific historical quotes.
- **narration:** English, spoken-style. Stay faithful to the source plot; don't invent
  dates, statistics, or real historical figures' words. If uncertain, phrase it as "as the
  story is often told…". Dialogue inside a folk tale is fine (it is a retelling).
- **highlight:** 1-2 short phrases per scene (the punchy words to color in the subtitle).
- **image_prompt:** English, concrete, culturally and era appropriate. No on-screen text,
  no logos, no real living people. The channel's visual_style is appended automatically.
- **motion:** `kenburns_in` or `kenburns_pan` for most scenes; `video` for only ~1 in 8
  (the most dramatic moments) to keep cost down.
- **Respect:** never mock a culture or religion. For sacred/indigenous stories, keep a
  reverent tone and note the tradition in the description.

## Hand-off

After pushing, the human reviews `script.md`, runs `autotube approve <episode>`, and the
scheduled GitHub Action renders and uploads (private) on Mon/Wed/Fri.
