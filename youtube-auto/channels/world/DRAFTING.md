# Drafting SOP — `world` channel (Mr.Untold / Forbidden History, English)

This is the brief the weekly drafting session follows. Goal: research and draft the next
batch of episodes as `plan.json` files, ready for the human to review. **Never approve.**

> This is a **factory**, not one-off videos. Every episode uses the **same proven
> retention skeleton (fixed)** with a **different true story (variable)**. Follow the
> skeleton exactly — `autotube approve` runs an automatic structure lint and **will refuse
> any episode that breaks it.** Quality stays constant even at 14 episodes/week.

## The channel

**Mr.Untold — "Forbidden History."** Provocative, imagination-stirring **true** stories
from world history: scandals, forbidden love, power and betrayal, shocking events, unsolved
mysteries. Pick the **juiciest, most surprising angle** of a real story and lead with it.

**Tone: documentary + mystery.** Measured, authoritative narrator voice (the trust of a
documentary) wrapped around a mystery-box structure (the pull of "what really happened?").
Think tabloid hook, documentary substance. Sensational and teasing, never cheap or false.

**Content mix:** make **scandal and forbidden love the main pillar — ~2 of every 3
episodes** (royal affairs, secret marriages, love that broke dynasties, court betrayals).
Fill the rest with shocking true events, character back-stories, and jaw-dropping "did you
know" history.

## Two hard rules

1. **Accuracy is #1.** These are presented as true.
   - Verify every claim with web search; note 2-3 reliable sources in your research.
   - **Never invent** dates, numbers, names, or quotes. Do not put made-up words in a real
     person's mouth. Dramatize the *situation*, not fabricated speech. Only use a direct
     quote if it is genuinely documented — then keep it exact.
   - Separate fact from legend when a story mixes both ("historians still debate…").
   - Avoid recent tragedies, living-person controversy/defamation.
2. **Advertiser-safe.** Suggestive and dramatic is good; **sexually explicit,
   pornographic, or gory is not** — those kill ad revenue. Imply and tease, don't show.

## The mandatory skeleton — the "open loop" engine

Every episode is **20–34 scenes (~5 min, ~700–800 words)**, a new image every ~8–10s
(~2 sentences / 25–40 words per scene). Tag each scene with a `role`. The spine:

| # | role | job |
|---|------|-----|
| 1 | `hook` | **0–15s.** The single most shocking image + a question or claim. Pose a mystery, don't answer it. "Why was her name erased from history?" |
| ~2–4 | `setup` | Who, when, where, what's at stake — only what's needed. |
| loop A | `loop_q` → `loop_fake` → `loop_problem` (→ `loop_reveal`) | Ask a question → give the official/expected answer (**the fake solution**) → show the evidence that breaks it (**the problem**). Hold the real answer. |
| ~40% | `second_hook` | Re-hook before the sag: "But the strangest part is something no one talks about…" |
| loop B | `loop_q` / `loop_problem` … | A second open loop, stacked on the first. |
| climax | `turn` | The forbidden / scandalous truth — the "신기한 포인트." The payoff image. |
| end | `payoff` | The real resolution; close the loops you opened. |
| last | `button` | One lingering line — an irony, an echo, or a question — to earn the comment and the next view. |

Allowed roles: `hook, setup, loop_q, loop_fake, loop_problem, loop_reveal, second_hook,
turn, payoff, button, context`.

**Golden rule of retention:** *never answer a question in the same breath you ask it.*
Push the answer one or more scenes later — that gap is what makes "the next scene"
irresistible (question → fake solution → problem → real solution).

**Writing craft:**
- Short sentences. End scenes on a small cliff-hanger ("…and by morning, she was gone.").
- One or two concrete, verifiable details per beat (a year, a number, a place) — real and
  memorable.
- Immersive storytelling, not an encyclopedia. No "and then, and then."
- Vary rhythm; let the narrator wonder aloud when history is genuinely unsure.

## Credit efficiency (plan where the money goes)

- Mark **4–6 scenes `is_key: true`** — the hook, the second hook, the turn, the payoff, the
  thumbnail source. Put your **best, richest `image_prompt`** on these.
- Non-key scenes get simpler prompts (establishing shots, textures, hands, landscapes) and
  can reuse a setting. The lint requires exactly 4–6 key scenes so cost stays bounded.
- `motion: video` on **only ~1 scene in 8** (most dramatic) — video frames are the
  expensive part. Everything else is `kenburns_in` / `kenburns_pan` (free camera move).

## The thumbnail (most important single asset)

- **`thumbnail_prompt` — over-invest here.** A bespoke, image-first thumbnail: one
  arresting visual, usually a dramatic **close-up of a face** with intense eye contact and
  raw emotion (desire, shock, grief, fear), cinematic lighting, shallow depth of field.
  Provocative but ad-safe (no nudity/gore, no on-screen text, no real living people).
- **`title`** — a curiosity-gap headline with a `|` subtitle. Tease, don't spoil ("The King
  Who Gave Up a Throne for Her | …"). Strong verbs, no clickbait lies. **The `|` is
  required.**
- **`thumbnail_text`** — leave `""` by default (modern thumbnails are image-first). Add 2–4
  words only if they truly add intrigue (renders small, bottom-left; the Mr.Untold wordmark
  is already overlaid).
- `thumbnail_scene` — fallback 1-based scene index if ever no `thumbnail_prompt`.

## What to produce each run

- Draft **14 episodes** (one week: 2 uploads/day × 7). Spread across **different
  continents and eras** (don't cluster one region). Weight toward scandal / forbidden love.
- Pick topics from `channels/world/topics.txt` with no episode yet, or research a fresh,
  genuinely surprising **true story**.

## Steps for each episode

1. **Research first** (web search): what happened, when, where, who, how it's commonly
   explained, and what's disputed. Note 2–3 sources.
2. Scaffold: `python -m autotube new world --topic "<Tale name (Country)>"`
3. Overwrite the generated `plan.json` with the real episode (schema + skeleton above).
4. **Self-check with `python -m autotube lint <episode>` until it passes** (see gate below).
5. Leave `status.json` as `approved: false`.
6. `git add -A && git commit` then push. Do **not** render or upload.

## plan.json schema

```json
{
  "topic": "Cleopatra and Mark Antony (Egypt / Rome)",
  "title": "The Queen Who Seduced Two Roman Titans | Cleopatra & Mark Antony",
  "thumbnail_prompt": "cinematic extreme close-up of an ancient Egyptian queen's face, kohl-lined eyes locked on the viewer, candlelit gold, shallow depth of field, tension",
  "thumbnail_text": "",
  "thumbnail_scene": 4,
  "description": "2-4 lines that tease the story. End with a one-line source note.",
  "tags": ["history","cleopatra","forbidden love","scandal","ancient rome","..."],
  "scenes": [
    { "narration": "...", "highlight": ["..."], "image_prompt": "...",
      "role": "hook", "is_key": true, "motion": "kenburns_in", "sfx": "..." }
  ]
}
```

Per scene: `narration` (English, spoken-style, accurate), `highlight` (1–2 punchy phrases to
color in the subtitle), `image_prompt` (English, concrete, era/culture appropriate; no text,
no logos, no real living people — the channel visual_style is appended automatically),
`role`, `is_key`, `motion`, optional `sfx`.

## The approval gate (automatic — do not bypass)

`autotube approve` **refuses** unless the structure lint passes. It checks, mechanically:
- `title` has `|`; `description` non-empty; ≥ 5 `tags`; `thumbnail_prompt` non-empty.
- 20–34 scenes; every scene has `narration`, `image_prompt`, and a valid `role`.
- Scene 1 is `hook`; there is a `second_hook`; **≥ 2 `loop_q`**; a `turn`; a `payoff`; the
  last scene is `button`.
- **4–6 scenes** with `is_key: true`.
- Warnings (won't block, but fix if you can): quote marks in narration (confirm it's a real,
  documented quote), word count outside ~700–800, second hook not near the 40% mark.

If `lint` is clean, the human reviews `script.md`, runs `autotube approve <episode>`, and the
render/upload step produces the private video + upload kit.
