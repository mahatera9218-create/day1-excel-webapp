# Drafting SOP — `world` channel (Mr.Untold, English)

This is the brief the weekly drafting session follows. Goal: research and draft the next
batch of episodes as `plan.json` files, ready for the human to review. **Never approve.**

> This is a **factory**, not one-off videos. Every episode uses the **same proven retention
> skeleton (fixed)** with a **different idea (variable)**. `autotube approve` runs an
> automatic structure lint and **refuses any episode that breaks the spec.**

## What this channel actually sells

**Mr.Untold sells the _curiosity gap itself_ — not a theme.** The topic is rarely new;
the **angle is the product.** Two formats, same goal (make someone think "I never thought
about it that way"):

- **Format B — "What If" (PRIMARY, `content_type: "what_if"`).** A real turning point,
  grounded in fact up to the branch, then **disciplined, plausible speculation** about how
  the world changes. This is the channel's main output and its niche: the most rigorous,
  cinematic "what if?" out there. Examples: *What if the Library of Alexandria never
  burned? What if the Black Death never happened? What if the Soviets reached the Moon
  first?*
- **Format A — "The Untold Angle" (secondary, `content_type: "true"`).** A real story seen
  through a **specific overlooked lens** nobody covers — a detail, a minor figure, a single
  decision. Use when a genuinely fresh factual angle exists. Example: not "the Titanic," but
  *"why the Titanic's lifeboats rowed away half-empty."*

**Theme is open.** Anything people have secretly wondered about — history, science,
civilization, nature, lost things, near-misses. Not limited to scandal. **Tone follows the
subject** (awe for a cosmic what-if, dread for a plague, intimacy for a love story).

### The niche rule (required on every episode)

`plan.json` must carry an **`angle`**: one line naming *what makes this not the version
everyone already knows.* If the angle is just the common summary, it fails the brief. Lead
the hook with that angle.

## Three hard rules

1. **Honesty about what's real.** Facts must be real; speculation must be labeled.
   - Verify the factual spine with web search; note 2–3 reliable sources.
   - **Never invent** dates, numbers, names, or quotes, and never put fabricated words in a
     real person's mouth. Separate fact from legend.
   - **What-if episodes:** everything *up to the branch point is real.* After it, make clear
     you are reasoning, not reporting ("from here, it's informed speculation…"). Set a
     `disclaimer` (required by the lint). The video also burns in a small "WHAT-IF SCENARIO"
     tag automatically, and scene 1 + the description must frame it as a scenario. This
     protects trust **and** ad revenue.
2. **Advertiser-safe.** Dramatic and provocative is good; **sexually explicit or gory is
   not.** Imply, don't show. Avoid recent tragedies and living-person defamation.
3. **Plain language — write for a 10-year-old.** Both narration and subtitles must be
   understandable by a child or someone brand-new to history. Use everyday words and short
   sentences. **No specialist/history-buff vocabulary** — the lint blocks words like
   *feudalism, serfdom, Malthusian, aristocracy, mercantilism, abdicate, dynastic, dowry,
   schism…* Explain the idea in simple words instead ("the old system where lords owned the
   land and poor farmers worked it"). Keep sentences short (lint warns past ~28 words). Never
   dumb down the *facts* — just the words.

## The mandatory skeleton — the "open loop" engine

Every episode is **20–34 scenes (~5 min, ~700–800 words)**, a new image every ~8–10s
(~2 sentences per scene). Tag each scene with a `role`:

| # | role | job (fact-angle / what-if) |
|---|------|------|
| 1 | `hook` | **0–15s.** Most arresting image + the premise as a question. "What if one fire never happened — and we lost a thousand years of progress?" |
| ~2–4 | `setup` | The real ground: who/when/what's at stake. (What-if: the true history up to the branch.) |
| loop A | `loop_q` → `loop_fake` → `loop_problem` (→ `loop_reveal`) | Ask → the obvious/official answer (**fake solution**) → the evidence that breaks it (**problem**). Hold the real answer. (What-if: pose the branch, then the first thing that changes, then the complication it creates.) |
| ~40% | `second_hook` | Re-hook before the sag: "But the strangest consequence is one nobody expects…" |
| loop B | `loop_q` / `loop_problem` … | A second open loop stacked on the first (consequences cascade). |
| climax | `turn` | The payoff idea — the branch's biggest divergence, or the scandalous truth. |
| end | `payoff` | Resolve the loops: the transformed world / the real resolution. |
| last | `button` | One lingering line — tie a what-if back to our real world, or an irony — to earn the comment and next view. |

Allowed roles: `hook, setup, loop_q, loop_fake, loop_problem, loop_reveal, second_hook,
turn, payoff, button, context`.

**Golden rule of retention:** *never answer a question in the same breath you ask it.* Push
the answer one or more scenes later — that gap is what makes the next scene irresistible.

**Craft:** short sentences; end scenes on a small cliff-hanger; one or two concrete,
verifiable details per real beat; immersive, not encyclopedic; vary rhythm.

## Asset reuse (aggressive — save credits)

Don't redraw what you can reuse. Two mechanisms, both understood by the lint and renderer:

- **`image_ref: <earlier scene number>`** — this scene reuses that earlier scene's image
  (same location/character returning, a motif, a recurring map). **No generation, no cost.**
  When a scene has `image_ref`, it needs no `image_prompt`.
- **`image_lib: "<key>"`** — reuse a channel-wide asset from
  `channels/world/assets_library/<key>.(png|jpg)` (shared maps, textures, establishing
  shots, recurring motifs). Keep an `image_prompt` too as a fallback for when the key isn't
  in the library yet. See that folder's README for naming.

Aim to **generate only the 4–6 `is_key` scenes richly**, and lean on reuse + simpler prompts
for the rest. Put `motion: video` on **only ~1 scene in 8** (video frames are the expensive
part); everything else uses free `kenburns_in` / `kenburns_pan`.

## Shorts — 2 dedicated teasers per episode

Shorts are **not** sliced from the long video (that gives weird, context-less fragments).
Write **2 purpose-built teaser scripts** in `plan["shorts"]`. Each is **self-contained**:

- **Structure:** a punchy hook question → 1–2 lines that deepen the mystery → **do NOT give the
  answer** → it ends on a CTA card automatically. ~**30–45s** (≈ 80–110 words), plain language.
- **Two different angles:** e.g. teaser 1 leads with the premise/hook; teaser 2 leads with the
  biggest twist ("the strangest part"). Don't just reword the same thing.
- **`scenes`:** 3–4 of the episode's strongest images to show, by scene number (reuses the
  long video's images → no extra image cost). Prefer `is_key` scenes.
- **Each short gets its OWN `title` and `description`** (it's uploaded separately to YouTube).
  Title: a short curiosity-gap line ending with `#shorts`. Description: 1–2 lines + a CTA to the
  full video + a couple of hashtags (e.g. `#shorts #history`). Keep both plain-language.
- **`highlight`:** 1–2 punchy phrases to color. **`cta`** optional (on-screen end card; defaults
  to a channel CTA). Never resolve the mystery — the point is to send viewers to the full video.

```json
"shorts": [
  { "title": "The choice that doomed a nation #shorts",
    "description": "A grounded what-if. Full story on the channel. #shorts #history",
    "narration": "What if the one choice that saved a nation… was the one that doomed it?",
    "scenes": [1, 6, 8], "highlight": ["doomed it"], "cta": "▶  Full story on the channel" },
  { "title": "Everyone's wrong about how this ended #shorts",
    "description": "The strangest part no one talks about. Full story on the channel. #shorts #history",
    "narration": "Everyone thinks they know how this ended. They are wrong about the strangest part.",
    "scenes": [14, 19, 23], "highlight": ["the strangest part"], "cta": "▶  Watch the full story" }
]
```

## The thumbnail (most important single asset)

- **`thumbnail_prompt` — over-invest.** One arresting visual, usually a dramatic close-up
  (a face, or the single iconic image of the what-if), cinematic light, shallow depth of
  field. Ad-safe; no on-screen text, no logos, no real living people.
- **`title`** — curiosity-gap headline with a `|` subtitle (the `|` is required). What-if
  titles usually start with "What If…". Tease, don't spoil; strong verbs; no clickbait lies.
- **`thumbnail_text`** — `""` by default (image-first). `thumbnail_scene` — fallback index.

## What to produce each run

- Draft **14 episodes** (one week: 2/day × 7). **Mostly what-if**, a few untold-angle facts.
- **Continental rotation (required).** Every episode sets `continent` to one of **Asia,
  Europe, Americas, Africa, Oceania**. Balance the batch across all five and **do not cluster
  on one country** — check the `continent` of episodes already drafted and spread out. (Pure
  "what-if-science/nature" ideas: tag the continent most tied to the story, or where the real
  events happened.)
- Spread across **different subjects and eras** too.
- Pull ideas from `channels/world/topics.txt`, or research a fresh one.

## Steps per episode

1. **Research the factual spine** (web search); note 2–3 sources and the real branch point.
2. Scaffold: `python -m autotube new world --topic "<Idea (Place/Field)>"`
3. Overwrite `plan.json` (schema below). Write the `angle` first — it drives everything.
4. **Run `python -m autotube lint <episode>` until it passes.**
5. Leave `status.json` as `approved: false`; `git add -A && git commit` and push. Don't render.

## plan.json schema

```json
{
  "topic": "What if the Library of Alexandria never burned? (Egypt / knowledge)",
  "continent": "Africa",
  "content_type": "what_if",
  "angle": "Not 'what we lost' — what specific technologies arrive centuries early, and who it hurts",
  "disclaimer": "A what-if scenario: real history up to the fire, then informed speculation.",
  "title": "What If the Library of Alexandria Never Burned? | A Different 2,000 Years",
  "thumbnail_prompt": "cinematic close-up of ancient scrolls glowing in lamplight inside a vast library, embers drifting, awe and tension, shallow depth of field",
  "thumbnail_text": "",
  "thumbnail_scene": 4,
  "description": "2-4 lines that tease it, clearly a what-if. End with a one-line source note.",
  "tags": ["what if","history","alexandria","alternate history","science","..."],
  "shorts": [ {"narration":"...","scenes":[1,6,8],"highlight":["..."],"cta":"..."}, {"...":"..."} ],
  "scenes": [
    { "narration": "...", "highlight": ["..."], "image_prompt": "...",
      "role": "hook", "is_key": true, "motion": "kenburns_in", "sfx": "..." },
    { "narration": "...", "image_ref": 4, "role": "context", "motion": "kenburns_pan" }
  ]
}
```

Per scene: `narration` (English, spoken, accurate on the factual parts), `highlight` (1–2
punchy phrases), `image_prompt` (English, concrete, era/field appropriate; no text/logos/real
living people — the channel visual_style is appended) **or** `image_ref` to reuse, optional
`image_lib`, `role`, `is_key`, `motion`, optional `sfx`.

## The approval gate (automatic — do not bypass)

`autotube approve` refuses unless the lint passes. It checks: non-empty `angle`; valid
`content_type` (and a `disclaimer` when `what_if`); valid `continent` (one of the five); no
blocked hard/jargon words in any narration (plain-language rule); `title` has `|`;
`description`; ≥ 5 `tags`; `thumbnail_prompt`; 20–34 scenes; each scene has `narration`, a
valid `role`, and either an `image_prompt` or a valid `image_ref`; scene 1 is `hook`; a
`second_hook`; ≥ 2 `loop_q`; a `turn`; a `payoff`; last scene is `button`; 4–6 `is_key`
scenes; **2 `shorts` teasers** (each with narration, valid scene refs, plain words).
Warnings (fix if you can): quote marks (confirm documented), long sentences
(>28 words), word count ~700–800, second hook near the 40% mark.
