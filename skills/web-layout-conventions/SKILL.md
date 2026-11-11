---
name: web-layout-conventions
description: >-
  Web page layout in CSS: overflow, type scale, spacing, tables and numbers.
  TRIGGER when: writing or editing CSS, Tailwind classes or inline styles;
  laying out a web page, table, card grid or dashboard; displaying numbers or
  amounts in HTML; user says a web UI looks cramped, misaligned, cut off or
  hard to scan.
  SKIP when: the interface is not rendered by a browser (native mobile,
  desktop toolkits, terminal), or the change touches no layout or styling.
---

# Web layout conventions

These rules hold for any page a browser renders — a React app, a server
template, a generated report. They are about where things sit and how big
they are; the words themselves are `ui-copy-conventions`' job, and the mobile-
first breakpoints are `frontend-conventions`'.

A data-dense page fails in the same few ways: text spilling out of its box,
the important value cut while there is room, numbers that cannot be compared
down a column, and gaps that do not say what belongs together. **Each rule
below has a check you can apply to a rendered page without debate.**

## Nothing leaves its box

- **Text never overflows its block, overlaps another, or makes the page
  scroll sideways.** Check at the narrowest viewport: the root element's
  `scrollWidth` equals its `clientWidth`.
- Fix in this order:
  1. **Let it wrap**: `overflow-wrap: anywhere` on text that can hold long
     unbroken strings (identifiers, URLs, e-mails), and `min-width: 0` on flex
     and grid children — their default `min-width: auto` refuses to shrink
     below their content, which is the usual cause of a page-wide scroll.
  2. **Shorten it**, with the full value reachable (below).
  3. **A wide table scrolls in its own container**, never the page:
     wrap it in `<div style="overflow-x: auto">`.

## The value that matters is never cut

- **Never truncate the main information of a row — its name, amount or
  status — while the row has room.** Give the width to the column that
  carries meaning; shrink or drop the one that does not.
- **When truncation is unavoidable, the full value stays reachable** on hover
  *and* on keyboard focus or tap: a `title` attribute alone shows nothing on a
  touch screen.
- **Numbers are never cut**, neither with an ellipsis nor by `overflow:
  hidden`. A number too wide for its column is scaled: one scale for the whole
  column, stated in its header — "Revenue (k€)" with `1,240` and `950` —
  never `1.2M` in one cell next to `950` in the next, which breaks the
  comparison down the column.
- **One wrapped label must not make one row in ten twice as tall.** Shorten
  the label, give every row the same sub-line for the secondary information,
  or truncate it with the full value reachable.

## Type hierarchy

- **Size follows importance, and is never inverted**: a heading is never
  smaller than the content it heads, a legend or a footnote never larger than
  what it labels, and annotations (units, timestamps, hints) take the
  smallest size.
- **Never flat either**: the page title, section titles and body text are
  visibly different sizes.
- **At most five font sizes and three weights** on a page, each defined once
  as a token (CSS custom property or the framework's theme scale) and used by
  name. No one-off `font-size: 13.5px`.
- **Table headers and labels stay readable**: no smaller than the smallest
  size of the scale, and no all-caps below body size.

## Spacing and grouping

- **One spacing scale** — for instance `4, 8, 12, 16, 24, 32, 48` px — as
  tokens or the framework's scale. Every margin, padding and gap comes from
  it: no `margin: 13px`, no `mt-[13px]`.
- **Proximity says what belongs together**: the gap inside a group is at
  least one step of the scale smaller than the gap between groups. An element
  between two blocks sits visibly closer to the one it belongs to — never
  equidistant, belonging to neither.
- **A value stays next to its unit and its annotation.** No
  `justify-content: space-between` pushing "(estimated)" to the far edge of
  the card. Join a number and its unit with a non-breaking space
  (`12&nbsp;kg`) so they never wrap apart.

## Blocks size to their content

- **A block is as wide as its content needs, not as wide as its container**:
  `max-width`, `width: fit-content`, or a grid of
  `repeat(auto-fill, minmax(16rem, 1fr))` rather than full-width blocks with
  one short line each.
- **Prose is capped at a readable line length**: `max-width: 75ch` on
  paragraphs.
- **Cards of different content keep different heights**:
  `align-items: start` on the grid rather than stretching every card to the
  tallest and leaving the others half empty.

## Tables and numbers

- **The column the user scans for comes first** after the row's identifier —
  a status or verdict is not the last column off the right edge.
- **Numbers are right-aligned**, with `font-variant-numeric: tabular-nums` so
  digits line up, and **the same number of decimals throughout a column**.
- **The unit lives in the header** ("Weight (kg)"), not repeated in each
  cell; `ui-copy-conventions` says the same of any value shared by every row.
- **A numeric column's header is aligned like its values**: right.
- **The actions column is aligned** — right, as the last column — with
  buttons of one width or icons of one size, in the same order on every row.
  An action unavailable on a row leaves its slot empty or disabled, so the
  others do not shift.

## One look per component

- **Each kind of component has one look**: every status badge the same shape
  and size, every primary button the same, every table the same row height
  and header style. A variant (danger, small) is a deliberate modifier of
  that look, defined once and named, not a one-off restyle at the call site.
- This is about what the user sees. Repeated markup becomes a shared
  component by the rule of three in `CLAUDE.md`: at the third copy, not
  before.
