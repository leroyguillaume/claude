---
name: web-layout-conventions
description: >-
  Web page layout in CSS: mobile-first, overflow, truncation, type scale,
  spacing, tables.
  TRIGGER when: writing CSS, Tailwind classes or inline styles; laying out a
  web page, table, card grid or dashboard; user says a web UI looks cramped,
  cut off or misaligned.
  SKIP when: the UI is not rendered by a browser, or no layout or styling
  changes.
---

# Web layout conventions

For any page a browser renders. Where things sit and how big they are; the
words are `ui-copy-conventions`. Each rule has a check that holds on the
rendered page.

## Mobile first

- **The styles outside any media query are the mobile layout**; wider layouts
  layer on with `min-width` breakpoints (Tailwind's `sm:` / `md:` / `lg:` are
  `min-width`). Never a `max-width` breakpoint layered down from a desktop
  base, never a default layout that assumes a wide viewport: at the narrowest
  viewport, no media query matches and the page reads as intended.

## Nothing leaves its box

- **Text never overflows its block, overlaps another, or scrolls the page
  sideways**. Check: each text element's box lies within its parent's, no two
  siblings' boxes intersect, and at the narrowest viewport the root's
  `scrollWidth` equals its `clientWidth`.
- Fix in this order: **wrap** (`overflow-wrap: anywhere` on long unbroken
  strings, `min-width: 0` on flex and grid children, whose default
  `min-width: auto` refuses to shrink and is the usual cause of a page-wide
  scroll); **shorten**, with the full value reachable; **scroll a wide table
  in its own `overflow-x: auto` container**, never the page.

## The value that matters is never cut

- **Never truncate a row's name, amount or status while the row has room**:
  give the width to the column that carries meaning.
- **A truncated value stays reachable on hover and on focus or tap**: a
  `title` alone shows nothing on a touch screen.
- **Numbers are never cut.** One too wide is scaled, with one scale per
  column stated in its header — "Revenue (k€)" — never `1.2M` next to `950`.
- **One wrapped label must not double one row's height**: shorten it, or give
  every row the same sub-line.

## Type hierarchy

- **Size follows importance, never inverted**: a heading is never smaller
  than what it heads, a legend never larger than what it labels.
- **Never flat**: page title, section titles and body are visibly different.
- **At most five font sizes and three weights**, each a token (CSS custom
  property or theme scale): no one-off `font-size: 13.5px`.
- **Table headers and labels stay at body size or one step below**, and never
  all-caps below body size.

## Spacing and grouping

- **One spacing scale** (`4, 8, 12, 16, 24, 32, 48` px) as tokens: no
  `margin: 13px`, no `mt-[13px]`.
- **The gap inside a group is at least one step smaller than between
  groups**; an element between two blocks sits closer to the one it belongs
  to.
- **A value stays next to its unit and annotation**: no `space-between`
  pushing "(estimated)" to the far edge; `12&nbsp;kg` so they never wrap
  apart.

## Blocks size to their content

- **`max-width`, `fit-content` or `repeat(auto-fill, minmax(16rem, 1fr))`**,
  not full-width blocks holding one short line.
- **Prose capped at `max-width: 75ch`.**
- **Cards keep their own heights**: `align-items: start` on the grid, not
  every card stretched to the tallest.
- **Items of one kind in a row or grid align on one edge**, whatever each
  holds: `align-items: start`, not `center` under captions of different
  heights, and an empty slot takes the same box as a filled one. Check: every
  item's visual has the same `getBoundingClientRect().top`.

## Tables

- **The column the user scans for comes right after the row's identifier**,
  not last off the right edge.
- **Numbers right-aligned with `font-variant-numeric: tabular-nums`**, the
  same decimals down a column, the header aligned like its values.
- **Actions in the last column, right-aligned**, buttons of one width or icons
  of one size, in the same order on every row; an unavailable one leaves its
  slot empty or disabled.

## One look per component

Every badge, button or table of a kind looks the same; a variant (danger,
small) is a named modifier defined once, not a restyle at the call site. When
repeated markup becomes a shared component is the rule of three in
`CLAUDE.md`.
