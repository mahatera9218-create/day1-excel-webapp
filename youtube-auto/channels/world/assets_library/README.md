# Channel asset library (`world` / Mr.Untold)

Reusable images shared **across episodes** to save generation credits. A scene references
one with `"image_lib": "<key>"` in `plan.json`; the renderer uses
`assets_library/<key>.(png|jpg|jpeg|webp)` directly instead of generating.

## Naming

Use short, descriptive, lowercase keys so the drafter can guess them:

```
world_map_old.png          # aged parchment world map
europe_map_medieval.png
space_earth_from_orbit.png
parchment_texture.png
candlelit_study.png        # a scholar's desk / recurring "narrator" setting
starfield.png
```

## Rules

- These are **generic, reusable backdrops / motifs** (maps, textures, establishing shots,
  recurring settings) — not episode-specific hero images. Those stay per-episode and go on
  the 4–6 `is_key` scenes.
- Still give such a scene an `image_prompt` as a **fallback** (used only if the key is
  missing here). The lint requires it.
- No on-screen text, no logos, no real living people — same as all channel images.
- To add one: drop the file here with a clear key name and commit it. (Note: the repo's root
  `.gitignore` ignores `*.png`, so add images with `git add -f`.)

Reuse **within** a single episode (a returning location) uses `"image_ref": <scene number>`
instead — no library entry needed.
