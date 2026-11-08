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

> **THIS IS A HISTORY CHANNEL — made OUTRAGEOUS, bold and deliciously cheeky.** Tabloid
> energy, documentary truth. Keep the SUBJECT historical (people, empires, events) — don't
> switch to science/animals/everyday trivia. Crank the TREATMENT as BOLD, provocative and
> taboo-flirting as you can: sex, scandal, gore, madness, greed, betrayal are great HOOKS —
> but **two hard limits: (1) 100% TRUE, never invent; (2) advertiser-safe — imply the dark/
> racy bits, never show gore or anything explicit.** The sweet spot is "I can't believe
> they're allowed to tell me this… and it's REAL." Mostly light & cheeky (~3 of 4), ~1 in 4
> deeper for variety. Never dry, never a lecture.

- **Format B — "What If" history (PRIMARY, `content_type: "what_if"`).** A cheeky, irresistible
  historical premise — real fact up to the branch, then playful, plausible speculation.
  Examples: *If Rome never fell. If Cleopatra had won. If the printing press came 500 years
  early. If the Library of Alexandria survived.* Lead with the fun, audacious angle, not a
  lecture.
- **Format A — "The Untold" true story (secondary, `content_type: "true"`).** A jaw-dropping,
  cheeky TRUE history story through a wild, overlooked lens. Examples: *the emperor who made his
  horse a senator; the medieval town that put a pig on trial; the war that started over a
  bucket; why Napoleon wasn't actually short.* Delightfully true, "I can't believe that's real."

**Keep the FEEL fun, witty and a little cheeky** — short punchy lines, vivid scenes, plain
language, a wink in the voice. The ~1-in-4 deeper episode can be weightier, but still with a
killer hook and plain words. The subject stays history; only the energy changes.

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

### Character consistency (important — the AI redraws faces differently each time)

AI image generation will NOT draw the same person the same way twice, so repeated close-ups of
"the same character" look like different people and break immersion. Two fixes, use both:
1. **Reuse ONE hero image for a recurring person.** Generate that character's image once (a
   strong portrait), then on every later scene where they appear, set `image_ref` to that
   scene. The face stays identical (it's literally the same image, with a fresh Ken Burns move).
2. **Lean on identity-light shots.** Favor scenes where exact likeness doesn't matter: wide
   shots, silhouettes, from behind, hands/objects/symbols, crowds, places, close-ups of a
   detail (a crown, a letter, a weapon) rather than a repeated front-on face. When a prompt does
   show a person, describe them concretely (era, clothing, hair, build) so separate generations
   at least rhyme. Don't scatter many different front-on close-ups of the same named person.
3. **Lock a REAL person's real appearance — and repeat it in EVERY prompt they appear in.**
   For an actual historical figure, decide their documented look up front (skin tone / ethnicity,
   age, build, hair, signature dress) and paste that SAME short description into every scene
   prompt that shows them. Never write a bare "the emperor" / "the king" — the AI will fill in a
   random (often wrong) ethnicity and flip it shot to shot. Getting a real person's race wrong is
   both inaccurate and offensive, so this is non-negotiable. Example lock: *"Mansa Musa, a
   dark-skinned West African man in his 40s, richly robed in gold-trimmed cloth and turban"* —
   use it verbatim in each of his scenes, and reuse one hero image via `image_ref` on top of that.

Aim to **generate only the 4–6 `is_key` scenes richly**, and lean on reuse + simpler prompts
for the rest.

**Shoot MOMENTS, not portraits (free drama).** Write every `image_prompt` as a dramatic instant
caught mid-action or mid-emotion — a hand flinging gold, a face frozen in shock, a figure lunging,
smoke curling, a blade half-drawn — with tight cinematic framing (a close or dynamic angle, strong
directional light, shallow focus), as if it were a still pulled from a film. Avoid flat, posed
portraits and plain wide "establishing" shots; even a setup scene should have tension in it.
**Front-load the drama:** the first 2–3 scenes (the cold-open / hook, the opening ~10–15 seconds)
must be your MOST arresting, highest-energy images of the whole episode — the single motion scene,
if any, usually belongs here. Hook the eye before the viewer can even think about scrolling, and
save the calmer, wider shots for the middle.

**Real motion (`motion: "video"`) — decide per episode, by the story.** Most scenes stay stills
with free camera movement (`kenburns_in` / `kenburns_pan`); figures don't actually move there.
A scene marked `motion: "video"` becomes a real ~5s moving clip (a figure genuinely dances,
walks, turns) — but video frames are the **expensive, slow** part, so spend them deliberately.
Judge each script on its own:
- Put `motion: "video"` **only where real movement carries the meaning** — a decisive action,
  the cold-open hook, the `turn`, a moment of motion the story is literally about (a battle, a
  dance, a chase, a collapse). If a scene works fine as a held image, leave it a still.
- **Rough budget: ~1–2 video scenes per episode (cost control).** Reserve motion for the single
  moment that most needs to move (usually the hook or the turn). Only an unusually action-driven
  story goes to 3; never more. Everything else is stills + camera move. (Video is the costly part.)
- Pick video scenes from the `is_key` beats where you can, and **never** put `motion: "video"`
  on an `image_ref`/reuse scene or a purely expository one.
- Lip-sync isn't done, so don't rely on a talking mouth — choose body/scene motion, not dialogue.

**Voices — narration vs drama (you decide per episode, like an editor).** By default the whole
episode is read by ONE narrator (documentary voice-over). Give a scene a different `voice` only
when the episode is genuinely built on spoken exchange — then characters sound distinct and it
plays like a drama. Let the format decide:
- **Narration-only (no `voice` fields) — the default and the majority.** Eyewitness, essay-style
  mysteries, butterfly, "if they saw us now", most true stories. One steady voice carries them.
- **Drama (multiple voices) — the dialogue formats:** mock interview with the dead, two-hander,
  era crossover, and any scene that is a real spoken exchange. Set `voice` on each speaking scene
  so each character is consistent; keep the narrator for the connective lines between them.
- **Voice palette (free edge-tts):** `narrator` (default channel voice), plus `m1` `m2` `m3`
  (distinct male) and `f1` `f2` `f3` (distinct female). Keep one alias per character for the
  whole episode. A raw edge voice name (e.g. `en-GB-RyanNeural`) also works if you need a specific
  accent.
- Same rails: **TRUE** → a character may only speak words that are actually documented; **WHAT-IF**
  → imagined lines are fine (the disclaimer covers it). No lip-sync, so write lines that land as
  pure audio, and don't turn every narration line into a character — most lines stay the narrator's.

## Shorts — 2 dedicated teasers per episode

Shorts are **not** sliced from the long video (that gives weird, context-less fragments).
Write **2 purpose-built teaser scripts** in `plan["shorts"]`. Each is **self-contained**:

- **Structure:** a punchy hook question → 1–2 lines that deepen the mystery → **do NOT give the
  answer** → it ends on a CTA card automatically. ~**30–45s** (≈ 80–110 words), plain language.
- **Two genuinely DIFFERENT angles — this is a hard rule, not a nicety.** The two teasers must
  not feel like the same short twice: use a different hook TYPE and different scenes for each.
  Teaser 1 opens on the absurd/intriguing PREMISE; teaser 2 opens on a specific weird DETAIL or
  moment from the middle (a strange object, a baffling tactic, one vivid beat). If you could swap
  their titles and nobody would notice, rewrite one. And **neither may reveal the outcome/answer**
  (e.g. don't say who won or how it ended) — both only open the loop, like the long-form title.
- **`scenes`:** 3–4 of the episode's strongest images to show, by scene number (reuses the
  long video's images → no extra image cost). Prefer `is_key` scenes.
- **Each short gets its OWN `title` and `description`** (it's uploaded separately to YouTube).
  Title: a short curiosity-gap line ending with `#shorts`. Description: 1–2 lines + a CTA to the
  full video + a couple of hashtags (e.g. `#shorts #history`). Keep both plain-language.
- **`highlight`:** 1–2 punchy phrases to color. **`cta`** optional (on-screen end card; default
  points to the description link). Never resolve the mystery — the whole point is the FUNNEL.
- **SHORTS → LONG-FORM FUNNEL (why shorts exist).** A short's job is to make the viewer NEED the
  answer, then send them to the full video. So: (1) tease the exact mystery the long-form pays
  off (same hook, no answer); (2) end on a CTA pointing to the full video — the uploader auto-
  puts the long-form link at the TOP of each short's description, so the CTA card should say
  "link in description" / "full story below"; (3) keep it under ~45s and punchy. The renderer
  AUTO-APPENDS a spoken "full story is in the description" line to the end of every short, so do
  NOT write that CTA into the short `narration` yourself (it would double up). (The owner can
  also add the long-form as the Short's native "Related video" in Studio — the strongest link —
  since the API can't set that automatically.)

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

## Formats — the show's DNA (this is what makes us different)

Mr.Untold doesn't *explain* history — it drops the viewer **inside** it. Every script is part
documentary, part drama, part thought-experiment. Two drama techniques are **always on**, and
every episode is built on **one format** chosen from the lists below.

**Always-on (bake into every episode):**
- **Cold open — scene 1 (`hook`) opens IN the moment, not with narration.** A tense beat, a
  sensory detail, present tense, 1–2 lines; make them feel they walked in on something.
- **Second-person pull.** Use "you" to drop the viewer into the scene wherever it fits ("You're
  standing in the Senate when…"). Immersion over lecture.

**Pick ONE format per episode and rotate (don't reuse the same format two days running):**

*TRUE formats — 100% real, `content_type: "true"`, no invented facts:*
- **Eyewitness time-traveler.** "You just landed in [real place], [real moment]" → show what you'd
  *actually* see, smell, hear. Time-travel is only the camera; every detail stays real.
- **Mock interview with the dead.** On-screen questions; the figure "answers" using only their REAL
  documented words/positions. Cheeky framing, sourced content.
- **Diary / letter.** Narrate a real surviving letter or diary in-character, scenes underneath.
- **History on trial.** Put a real person/act on trial; withhold the verdict until the `payoff`.
- **Two-hander.** Reenact a documented real conversation or confrontation as a scene.

*WHAT-IF formats — imaginative, `content_type: "what_if"` + `disclaimer`. The person's real
traits/achievements stay accurate; only the SITUATION is moved, and you say so in one line.
Ad-safe; anachronisms are allowed here (that collision IS the fun):*
- **Fish out of water.** Drop a real figure into another era; let their true character react
  (*"Caligula with a Twitter account"*).
- **Right person, wrong time.** A real genius with a tool from another age (*"Da Vinci + one laptop"*).
- **Era crossover.** Two real figures from different times meet or clash, each using their real methods.
- **If they saw us now.** A figure judges the modern world through their real values.
- **Butterfly effect.** Change ONE real decision at a real turning point; dramatize the ripple.

**Serialized seasons (occasional).** Connect 3–5 episodes into an arc (e.g. *"The Mad Emperors"*),
reuse the hero image via `image_ref`, and end each on a cliffhanger for the next.

**Anachronism rule.** TRUE formats stay era-accurate — no modern objects. WHAT-IF displacement
formats *should* mix eras on purpose. Either way, the person's documented facts never change.

## Title & thumbnail — HOOKING IS LIFE (the make-or-break)

Half the effort goes here. A perfect script with a weak title/thumbnail gets zero views.

> **THE ONE RULE: provoke curiosity, NEVER reveal the answer.** The title and thumbnail open a
> loop in the viewer's head — a question, a mystery, an "wait, HOW/WHY/WHO?!" — and the video
> is the only place to close it. Never give away the punchline, the reveal, or the resolution in
> the title or the image. If someone could read the title and feel "ok, got it" without
> clicking, it has FAILED. Make them NEED to watch to find out.
> *Bad (spoils): "Rome's Most Powerful Senator Was a Horse."* →
> *Good (withholds): "Rome's Most Powerful Senator Wasn't Even Human."*
> *Bad: "They Dug Up a Dead Pope to Put Him on Trial."* →
> *Good: "They Put a Rotting Corpse on Trial — the Verdict Changed Everything."*

**Proven hook patterns — steal these. Each opens a loop and refuses to close it:**
- **Concrete anomaly.** Start from one weird, specific, everyday detail that shouldn't exist, and
  make *that* the mystery — *"A smell of smoke, in a house where no one had ever lit a fire."* The
  oddity demands an explanation the title never gives.
- **"The culprit was…".** Frame it as a whodunit, then cut away right before the reveal — *"Thousands
  vanished, and the thing to blame was something no one thought to suspect."*
- **Paradox / broken expectation.** State a contradiction, withhold the why — *"Roman concrete lasts
  2,000 years. We forgot how to make it."*
- **Personal stake.** Put a real person in a gut-punch — *"He won the entire war in 38 minutes. It
  destroyed him."*
- **Designed cutoff.** YouTube truncates titles (~first 45–55 chars on mobile) — front-load the hook
  so even the cut-off version still teases, and let the sentence trail toward the mystery, not the
  answer.

- **`title` — HARD, bold hooks that WITHHOLD the answer. DO NOT start every title with "What
  if".** Push it as provocative as the TRUE story allows, but open a loop and never close it.
  Rotate hook styles so the feed never looks repetitive — all of these tease without spoiling:
  a withholding claim (*"This Emperor Declared War on Something That Can't Fight Back"*), a taboo
  tease (*"Rome's Most Powerful Senator Wasn't Even Human"*), a cheeky question (*"Why Would
  Anyone Put a 400-Year-Old Corpse on Trial?"*), a "The ___ who ___" with the twist hidden
  (*"The King Whose Own Joke Killed Him"*), a number (*"The War That Was Over Before Breakfast"*),
  or a dare (*"They Don't Teach You This Because It's Too Insane"*). Keep a `|` subtitle
  (required). Bold but never a lie, never explicit/gory wording, and **never the answer.** ≤1 in
  5 may use "What if".
- **`thumbnail_prompt` — over-invest, this is #1.** One split-second-arresting visual that
  **poses a question, never answers it.** Usually a dramatic CLOSE-UP of a face mid-emotion
  (shock, mischief, fear, awe) with intense eye contact, bold cinematic light, shallow depth of
  field — a moment that makes you go "wait, what's happening here?!", not the resolution. Show
  the intrigue, hide the payoff. Ad-safe; **no baked-in words** (text is overlaid separately, so
  don't ask the image for any), no logos, no real living people.
- **`thumbnail_text` — FILL IT, don't leave it empty.** A punchy **2–4 word** hook, drawn BIG over
  the image, that teases without spoiling: *"NOT HUMAN"*, *"38 MINUTES"*, *"THE WRONG BODY"*, *"STILL
  THERE"*. Keep it **≤ ~18 characters** so it stays huge and thumb-readable; put the mystery in it,
  never the answer. `thumbnail_scene` — fallback scene index when there's no prompt.

## What to produce each run

- Draft **2 episodes per run (daily)** — small, steady batches, not a weekly pile.
- **Keep the running mix ~3:1** light/cheeky to deeper: most days both are light & fun; roughly
  **every 4th day make one of the two a deeper/meatier episode.**
- **Continental rotation (required).** Every episode sets `continent` to one of **Asia, Europe,
  Americas, Africa, Oceania**. Rotate day to day and **don't repeat the same continent/country
  as the last few days** — look at recent episodes under `episodes/world/` and spread out.
- Spread across **different subjects and eras** too; don't repeat a topic already drafted.
- **Rotate formats (see "Formats — the show's DNA").** Build each episode on one format and vary
  them day to day — never the same format two days running. Cold-open + second-person stay on for
  all of them. Keep the ~3:1 light:deep mix across the format rotation.
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
`image_lib`, `role`, `is_key`, `motion`, optional `sfx`, optional `voice` (character voice — see
"Voices"; omit for the narrator).

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
