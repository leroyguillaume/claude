---
name: frontend-conventions
description: >-
  Frontend code: TypeScript, React, Biome, mobile-first.
  TRIGGER when: editing `.tsx`, `.ts` in a frontend app, or React components,
  hooks or pages; touching a frontend `package.json`, `tsconfig*.json`,
  `biome.json`/`.jsonc` or lockfile; styling or laying out UI; user asks about
  frontend tooling, React or Biome.
  SKIP when: server-side TypeScript (Node backends, CDK, Pulumi) or no
  frontend code.
---

# Frontend conventions

**Always:**

- Write **everything in TypeScript**. Application source is `.ts` / `.tsx`
  only. New UI is `.tsx`; non-UI modules are `.ts`.
- Build **all UI with React** using function components and hooks. Type props
  and state explicitly; type component return values where it aids clarity.
- Enforce **strict typing**. `tsconfig.json` must set `"strict": true` (this
  turns on `noImplicitAny`, `strictNullChecks`, and the rest of the strict
  family). Additionally enable `noUncheckedIndexedAccess` and
  `exactOptionalPropertyTypes`. Treat `tsc --noEmit` as a **blocking gate**,
  on the same footing as Biome — fix every type error before a change is
  done. Run `tsc --noEmit` via pre-commit, which CI runs.
- Format and lint with **Biome** (`biome check --write`). It replaces both
  ESLint and Prettier. Configure everything in `biome.json` (or
  `biome.jsonc`). Enable the recommended rules and set
  `suspicious/noExplicitAny` to `error`.
- Add a **Biome pre-commit hook** as a local `language: system` hook running
  the lockfile's Biome (`npm run lint`, or `npx biome check`), alongside the
  baseline hooks from `pre-commit-conventions`. Not `biomejs/pre-commit`: its
  `additional_dependencies` is a second Biome version to keep in step. CI runs
  `npm ci` before `pre-commit` so the hook finds Biome.
- **Exclude the frontend lockfile from `check-added-large-files`**, as
  `pre-commit-conventions` describes for every lockfile.
- Design **mobile-first**. Base, unprefixed styles target the smallest
  viewport; layer larger layouts additively with `min-width` breakpoints
  (or the framework's `sm:` / `md:` / `lg:` responsive prefixes, which are
  themselves `min-width`-based). The default, no-media-query rendering must
  be the mobile layout.
- Model structured data with an **explicit `type` / `interface`**, never a
  bare inline object shape threaded through the code. First reuse a type a
  dependency already ships (an SDK's request/response model, a generated API
  client, library prop types); only define your own when none exists. Derive
  rather than duplicate (`Pick`, `Omit`, `ReturnType`, `z.infer`, …).
- Validate data crossing an I/O boundary (API responses, form input, URL
  params, `localStorage`) with a schema validator (e.g. `zod`) and infer the
  TypeScript type from the schema, so the runtime shape and the static type
  cannot drift.
- Apply `logging-conventions`. Frontend mechanics: use one structured logger
  module configured at app startup, and log key-values
  (`logger.debug("fetch.done", { url, status })`), never by interpolating
  values into the message string. Gate verbosity by a log level the app's
  config module reads once (`import.meta.env.VITE_LOG_LEVEL`, see
  `config-conventions`), never read inline at the call site.
- Provide **tests** for components and logic with Vitest + React Testing
  Library (or the framework's first-party test runner). Test behaviour
  through the rendered output and user interactions, not implementation
  details.

**Never:**

- **Never use the `any` type.** Reach for `unknown` plus narrowing, a generic,
  or a precise type instead. If `any` is genuinely unavoidable (an untyped
  third-party module), isolate it behind a typed boundary and annotate the
  single line with `// biome-ignore lint/suspicious/noExplicitAny: <reason>`
  explaining why. Never use a blanket `any` to make a type error disappear.
- Never weaken the type checker: do not set `strict: false`,
  `noImplicitAny: false`, or sprinkle `@ts-ignore` / `@ts-expect-error` /
  `as` casts to silence `tsc`. A cast or suppression needs a one-line comment
  saying why the checker is wrong and why it is safe; prefer fixing the type.
- Never write application code in `.js` / `.jsx`, and never ship plain
  JavaScript modules for app logic. (Config files a tool requires in JS are
  the only exception.)
- Never use ESLint or Prettier, and never add an `.eslintrc*` or
  `.prettierrc*`. Biome owns formatting and linting; all config lives in
  `biome.json`.
- Never write **desktop-first** styles — no `max-width` breakpoints layered
  down from a desktop base, and no default layout that assumes a wide
  viewport. Start at mobile and scale up.
- Never use class components or legacy lifecycle methods; function components
  and hooks only.
- Never thread an untyped or inline-shaped object between components or
  functions as a stand-in for a known record — define the `type`/`interface`
  and use it, deriving from an existing type where possible.
- Never use `console.log` (or `console.*`) for diagnostics; route everything
  through the configured structured logger.
