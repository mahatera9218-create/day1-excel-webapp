# Drafting SOP — `world` channel (세계 야담 / hidden stories & anecdotes, English)

This is the brief the scheduled drafting session follows. Goal: research and draft the
next few episodes as `plan.json` files, ready for the human to review. **Never approve.**

This channel is **"world 야담"**: provocative, imagination-stirring **true** stories from
world history — scandals, forbidden love, power and betrayal, shocking events and unsolved
mysteries. The tone is **sensational and teasing** (bold hooks, juicy details,
cliffhangers that make people lean in), but every episode is **grounded in fact**.

Pick the **juiciest, most surprising angle** of a true story and lead with it. Think
tabloid hook, documentary substance.

**Content mix (what to weight):** make **scandal and forbidden love the main pillar —
roughly 2 of every 3 episodes** (royal affairs, secret marriages, love that broke
dynasties, betrayals at court). Fill the rest with variety: shocking true events,
character behind-the-stories, and jaw-dropping "did you know" trivia. When the weekly
batch is drafted, lean it toward scandal / forbidden love.

**Advertiser-safe line (important for monetization):** suggestive and dramatic is good;
**sexually explicit, pornographic, or gory is not** — those kill ad revenue. Imply and
tease rather than show. No recent real crimes or living-person defamation.

**Accuracy is the #1 rule.** These are presented as true, so:
- Verify every claim with web search; note 2-3 reliable sources in your research.
- **Never invent** dates, numbers, names, or quotes. Do not attribute made-up quotes to
  real people. If a detail is uncertain or disputed, say so ("historians still debate…").
- Clearly separate fact from legend when a story mixes both.
- Avoid recent tragedies, living-person controversy, and anything advertiser-unfriendly.

## What to produce each run

- Draft **4 episodes** (enough for one week of 3 uploads + buffer).
- Spread them across **different continents** (don't do four from one region).
- Pick topics from `channels/world/topics.txt` that have no episode yet, or research a
  fresh, genuinely surprising **true story or historical anecdote**.

## Steps for each episode

1. **Research first.** Use web search to confirm the facts: what happened, when, where,
   who, and how it is commonly explained. Note 2-3 sources. If accounts conflict, pick the
   mainstream scholarly version and say so in the description.
2. Scaffold: `python -m autotube new world --topic "<Tale name (Country)>"`
3. Overwrite the generated `plan.json` with the real episode (schema below).
4. Leave `status.json` as `approved: false`.
5. `git add -A && git commit` then push. Do **not** render or upload.

## plan.json schema and rules

```json
{
  "topic": "Cleopatra and Mark Antony (Egypt / Rome)",
  "title": "The Queen Who Seduced Two Roman Titans | Cleopatra & Mark Antony",
  "thumbnail_text": "SHE SEDUCED TWO EMPIRES",
  "thumbnail_scene": 4,
  "description": "2-4 lines. End with a one-line source note.",
  "tags": ["history","cleopatra","forbidden love","scandal","ancient rome", "..."],
  "scenes": [ { "narration": "...", "highlight": ["..."], "image_prompt": "...", "motion": "kenburns_in", "sfx": "..." } ]
}
```

- **Hook everything to the maximum (within the ad-safe line).**
  - **title:** a bold, curiosity-gap headline with a `|` subtitle. Tease the scandal/love
    ("The King Who Gave Up a Throne for Her"), don't spoil it. Strong verbs, no clickbait lies.
  - **thumbnail_prompt (most important):** a bespoke, image-first thumbnail. Describe the
    single most arresting visual — usually a dramatic CLOSE-UP of a face with intense eye
    contact and emotion (desire, shock, fear), strong lighting, shallow depth of field.
    The IMAGE sells the click, not text. Make it provocative but ad-safe (no nudity/gore).
  - **thumbnail_text:** leave `""` by default (modern thumbnails are image-first). Only add
    2-4 short words if they truly add intrigue; it renders small, bottom-left.
  - **thumbnail_scene:** fallback scene index (1-based) if no thumbnail_prompt is given.
  - Suggestive, dramatic, emotionally charged = good. Explicit, gory, or false = not.

- **Length & pacing:** target **~9-10 minutes** (~1,300-1,500 words) — long enough to
  clear the 8-minute mark for mid-roll ads, short enough to hold retention. **Keep each
  scene short so the image changes every ~6-9 seconds**: 1-2 sentences per scene (~15-30
  words), roughly **50-80 scenes**. Long scenes make it drag; split into two beats + two
  images when in doubt.
- **Scene 1 is the hook:** a striking question or image in the first 5 seconds.
- **Tell it as an immersive story, not a summary.** Build a clear arc: setup → rising
  tension → turning point → resolution. Use sensory, concrete detail (sound, light,
  weather), vary sentence rhythm, and end scenes on small cliff-hangers that pull the
  viewer forward. Avoid encyclopedic "and then, and then" narration.
- **Build drama without faking facts.** Make it vivid through scene-setting, pacing and
  the narrator's voice — not invented dialogue. **Do NOT put made-up quotes in real
  people's mouths.** Only use a direct quote if it is genuinely documented (and then keep
  it exact). Dramatize the *situation*, not fabricated speech.
- **narration:** English, spoken-style, and factually accurate. Don't invent dates,
  numbers, names, or quotes. When something is uncertain or debated, say so plainly
  ("no one is sure why", "historians still argue about this") — the mystery is part of
  the appeal.
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
