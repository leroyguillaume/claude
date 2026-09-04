---
name: rust-http-conventions
description: >-
  Rust HTTP/API stack conventions — `axum` + `aide` + Scalar with no
  exceptions, `schemars` DTOs, the OpenAPI document served at `/openapi.json`,
  and `validator` for input at the edge. Includes the `aide` wiring traps that
  surface as cryptic `OperationHandler` bound failures or endpoints that
  silently document nothing.
  TRIGGER when: editing or creating a Rust HTTP handler, router, extractor, or
  request/response DTO; adding or changing an endpoint in a Rust service;
  wiring `axum`, `aide`, `schemars`, Scalar, or `validator`; choosing `aide`
  feature flags; serving or generating an OpenAPI document from Rust; user asks
  about Rust web frameworks, OpenAPI generation, API docs, multipart uploads,
  body limits, or input validation in this repo.
  SKIP when: the Rust work has no HTTP surface (CLI, library, worker, data
  layer) — use `rust-conventions`; or the question is language-agnostic API
  design (DTO shape, JSON casing, pagination) — use `api-conventions`.
---

# Rust HTTP/API conventions

Applies on top of `rust-conventions` (language and tooling) and
`api-conventions` (wire contract: dedicated DTOs, `camelCase` JSON, pagination,
tagged operations). This skill is the Rust-specific stack and its wiring.

**Always:**

- **Every HTTP server / API uses the same stack, always: `axum` + `aide` +
  Scalar — no exceptions.** Never expose a bare `axum::Router` for an API:
  build the router with `aide`'s `ApiRouter` (drop-in for `axum`), document
  every endpoint, and serve the generated OpenAPI document.
- Generate the OpenAPI document with **`aide`** (its `ApiRouter` drop-in for
  `axum`) and **`schemars`** (derive `JsonSchema` on every request/response
  DTO). Serve the spec at `/openapi.json` and an interactive **Scalar**
  reference at `/docs` (via `aide`'s `scalar` feature).
- Validate deserialised input (request DTOs, config payloads, …) with the
  **`validator`** crate (derive API), not hand-rolled checks. Put
  `#[derive(Validate)]` on the input struct, use the built-in field
  validators (`length`, `range`, `email`, `url`, `nested`, …) where they
  fit, and `#[validate(custom(function = path::to::fn))]` for
  domain-specific rules — the function takes `&T` and returns
  `Result<(), validator::ValidationError>`, and in `validator` ≥ 0.19
  `function` is a **bare path**, not a string literal. Call `value.validate()?`
  at the edge (e.g. the `axum` handler) and provide a
  `From<validator::ValidationErrors>` for your error type so it maps to a
  `422`. Keep cross-entity / database-backed checks (e.g. "this id must
  belong to that parent") in the repository/service layer; `validator`
  covers field-level shape only. Add it with
  `cargo add validator --features derive`.
- Pass the graceful-shutdown future from `rust-conventions` to
  `axum::serve(..).with_graceful_shutdown(shutdown_signal())`.

**Never:**

- Never expose an HTTP API without `aide` + Scalar: no bare `axum::Router`
  for an API, no hand-written OpenAPI, no alternative docs UI. Every endpoint
  is documented and the spec is served at `/openapi.json` with Scalar at
  `/docs`.
- Never use a different web framework when `axum` fits the need.
- Never hand-roll input validation (bespoke `validate()` methods returning
  `Result<(), String>`, ad-hoc field checks scattered through handlers)
  when the `validator` derive can express it, and never pull in another
  validation crate when `validator` fits.

## `aide` wiring, learned the hard way

Most of these surface as a cryptic `OperationHandler` bound failure, or as an
endpoint that compiles and documents nothing.

- Enable the `aide` features `axum, axum-json, scalar, macros` — the base
  `axum` feature does **not** make `axum::Json` an `OperationInput`/`Output`,
  so without `axum-json` no JSON handler satisfies `OperationHandler`.
- Call `aide::generate::extract_schemas(true)` once before building the
  router so types are emitted as reusable `#/components/schemas` `$ref`s.
- Implement `aide::OperationOutput` (a no-op `type Inner = ()` is enough) for
  your error type so `Result<_, AppError>` is a valid documented return.
- Document path/query parameters with **named structs** (`Path<GamePath>`,
  not `Path<Uuid>` / `Path<(Uuid, Uuid)>`); `aide` derives parameter names
  from the struct fields, so bare/tuple extractors document no parameters.
- The `(StatusCode, Json<T>)` tuple documents **no** response; declare the
  success status of creates explicitly with
  `post_with(handler, |op| op.response::<201, Json<XxxResponse>>())`.
- Pin the `schemars` version `aide` re-exports (0.9 for `aide` 0.15) and add
  its `chrono04` / `uuid1` features for `DateTime`/`Uuid` fields.
- `OperationInput` for `Query<T>` is behind `aide`'s **`axum-query`** feature.
  A handler taking `Query<_>` fails the `OperationHandler` bound (cryptically)
  until you enable it, so the feature set is usually
  `axum, axum-json, axum-query, scalar, macros`. A custom extractor likewise
  needs a (no-op) `impl OperationInput`.
- For file uploads, take axum's `Multipart` extractor (`multipart/form-data`,
  one field per file → supports several files in one request). Enable **two**
  features: `multipart` on `axum` and **`axum-multipart`** on `aide` (the
  latter provides `Multipart`'s `OperationInput`, else the `OperationHandler`
  bound fails). axum's default request body limit is only **2 MiB**, far too
  small for PDFs — raise it per route with
  `post_with(handler, …).layer(DefaultBodyLimit::max(N))`
  (`aide`'s `ApiMethodRouter` has `.layer`, so the limit stays scoped to the
  upload route rather than the whole API).
- Add an `example` to a request/response schema with
  `#[schemars(extend("example" = serde_json::json!({...})))]` — the
  auto-generated placeholder (`"string"`, `null`) reads poorly in Scalar.
- Keep infrastructure endpoints (liveness/health probe, metrics, …) **out of
  the OpenAPI document**: register them with plain `route(...)`, not
  `api_route(...)`. The documented surface is the product API, not the ops
  plumbing.
- Do **not** serve `aide`'s bundled Scalar via `Scalar::axum_route()` — the
  vendored build renders with broken CSS. Serve your own `/docs` HTML that
  loads the current Scalar from its CDN
  (`https://cdn.jsdelivr.net/npm/@scalar/api-reference`) pointed at
  `/openapi.json`. (Trade-off: `/docs` then needs network access; acceptable
  for a dev docs page.)
- If the API has authentication, **document it in OpenAPI**: register the
  scheme once via `finish_api_with(&mut api, |t| t.security_scheme("BearerAuth",
  SecurityScheme::Http { scheme: "bearer", bearer_format: Some("JWT"), .. }))`
  and require it per protected operation with
  `op.security_requirement("BearerAuth")`. Leave public operations (login,
  public reads) without a requirement. This makes Scalar show the lock icon
  and a token input.
