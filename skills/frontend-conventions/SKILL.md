---
name: frontend-conventions
description: Frontend project conventions (TypeScript, React, Biome, enforced
  typing, mobile-first). TRIGGER when: editing or creating `.ts`/`.tsx` files;
  touching `package.json`, `tsconfig*.json`, `biome.json`/`biome.jsonc`, or a
  frontend lockfile; adding/removing a frontend dependency; building a React
  component, hook, or page; styling or laying out UI; user asks about frontend
  tooling, types, React, Biome, or responsive/mobile layout in this repo.
  SKIP when: pure backend/infra work (Python/Rust/Helm/Docker/CI) with no
  frontend file touched and the user isn't asking about the frontend.
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
  done. Wire `tsc --noEmit` into both `.pre-commit-config.yaml` and CI.
- Format and lint with **Biome** (`biome check --write`). It replaces both
  ESLint and Prettier. Configure everything in `biome.json` (or
  `biome.jsonc`). Enable the recommended rules and set
  `suspicious/noExplicitAny` to `error`.
- Add a **Biome pre-commit hook** (`biomejs/pre-commit`) running
  `biome check`, alongside the baseline hooks from `CLAUDE.md`.
- **Exclude the frontend lockfile from the `check-added-large-files`
  baseline hook.** A committed `package-lock.json` (or `pnpm-lock.yaml` /
  `yarn.lock` / `bun.lockb`) is legitimately large and must stay versioned,
  so it should never trip the large-file check. Add an `exclude` to that hook
  rather than raising `--maxkb` for everything:
  ```yaml
  - id: check-added-large-files
    exclude: ^package-lock\.json$
  ```
  Widen the pattern to match whichever lockfile(s) the repo uses.
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
- Apply the **Logging and observability** rules from `CLAUDE.md`. Frontend
  mechanics: use one structured logger module configured at app startup, log
  key-values (`logger.debug("fetch.done", { url, status })`), and gate
  verbosity by a log level read from the environment
  (`import.meta.env` / `process.env`), never by interpolating values into the
  message string.
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
