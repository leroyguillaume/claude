---
name: logo-conventions
description: >-
  Project logos and icons: SVG, redrawn faithfully from a raster.
  TRIGGER when: a raster logo or project icon (`logo.png`, `icon.png`, a
  `.jpg`/`.webp`) is added, committed or referenced from a README `<img>` or a
  site config; user asks about the logo's format.
  SKIP when: a screenshot, a photograph, a plot of data, or a diagram
  (`diagram-conventions`).
---

# Logo conventions

**A project's logo is an SVG file.** A logo that exists only as a PNG, JPG or
WebP is redrawn as SVG, and the SVG becomes the logo file.

- **It scales.** The same file serves a 200 px README header, a docs site
  header and a 16 px favicon, sharp on every screen; a raster blurs at any size
  but the one it was exported at.
- **It is small and it diffs.** A flat logo is a few hundred bytes of text, and
  a colour change shows up in review as a changed hex value.
- **Its colours are readable from the source.** A docs theme takes its palette
  from the logo (`starlight-conventions`); in an SVG that is a `fill` to read,
  not a pixel to sample.

## Redrawing it

When a vector original exists — the designer's SVG, PDF or AI file, a brand
kit — start from it rather than redrawing. Otherwise write the SVG by hand:

- **A `viewBox`, no fixed `width`/`height`** on the root element, so whoever
  embeds it decides the size.
- **Flat shapes and paths**: `<rect>`, `<circle>`, `<path>`, `<polygon>`, and a
  `<linearGradient>` only where the original really has one.
- **Colours as hex** (`#1f6feb`), taken from the original's pixels, not
  guessed.
- **Text as paths.** A `<text>` element renders in whatever font the viewer
  has installed, so a wordmark drawn with one changes shape from one machine to
  the next.
- **No embedded raster.** An `<image>` holding a base64 PNG inside an `.svg` is
  a PNG in disguise: none of the reasons above survive it. Never acceptable.

An auto-tracer (`vtracer`, `potrace`) is an option only when it is already
installed; installing one is a system package, and that needs the user's yes
first. Its output is a starting point: thousands of nodes and near-duplicate
colours, to simplify and then hold to the same check as a hand-drawn file.

## Fidelity comes first

**A logo is the project's identity, and an approximate SVG is worse than the
original PNG.** A blurry logo is still the logo; a redrawn one with the wrong
curve, a shifted colour or a different letterform is a different logo.

So before replacing anything, render the SVG to a raster at the original's
size and **look at both images side by side**:

```sh
rsvg-convert -w <original-width> logo.svg -o /tmp/logo-render.png
```

On macOS without `rsvg-convert`, `qlmanage -t -s 512 -o /tmp logo.svg` writes
`/tmp/logo.svg.png`; a browser works anywhere. Open the render and the original
and compare them, rather than trusting the markup:

- **Shapes and proportions** match: same outline, same spacing, same alignment.
- **Colours** match: the same hex values, the same transparency.
- **Text** matches: same letterforms, weight and kerning.

Iterate until they do. **When the logo is too detailed to redraw faithfully** —
photographic, heavy gradients, textures, an intricate illustration — keep the
raster, commit no approximation, and tell the user what could not be
reproduced and why.

## After a faithful redraw

- **The SVG replaces the raster.** Every reference points at the SVG — the
  README `<img>` (`readme-conventions`), the docs site config and favicon, the
  package manifest — and the raster file is deleted in the same change; git
  keeps the old one.
- **Keep the path the repository already uses**, changing only the extension:
  `assets/logo.png` becomes `assets/logo.svg`. Moving it is a separate change.
- **A raster exists only where a consumer requires one** — GitHub's social
  preview image, an app-store or package-registry icon. It is exported from the
  SVG at the size that consumer asks for (`rsvg-convert -w 1280 logo.svg -o
  logo-1280.png`), and re-exported whenever the SVG changes. The old raster is
  never kept as a second source: two files that both claim to be the logo drift
  apart.
