---
name: rust-conventions
description: Rust project conventions (clap, tokio, axum, tracing, mockall,
  static dispatch, cargo-chef for Docker builds).
  TRIGGER when: editing or creating `.rs` files; touching `Cargo.toml`,
  `Cargo.lock`, or `rust-toolchain*`; adding/removing a Rust dependency; setting
  up a Rust CLI, HTTP server, async trait, mock, or logging subscriber; user asks
  about Rust tooling, deps, traits, async, clippy, or rustfmt in this repo.
  SKIP when: pure Python/Helm/Docker/CI work with no Rust file touched and the
  user isn't asking about Rust.
---

# Rust conventions

**Always:**

- Prefer **static dispatch** over dynamic dispatch. Use generics with trait
  bounds or `impl Trait` rather than `Box<dyn Trait>` / `&dyn Trait`. Reach
  for trait objects only when static dispatch is genuinely impossible (e.g.
  heterogeneous collections, recursive types, or a hard binary-size
  constraint), and leave a one-line comment explaining why.
- Prefer **argument-position `impl Trait`** over a named generic parameter
  when the parameter's type is used only once and never needs to be named.
  Write `fn run(handler: impl Handler)`, not
  `fn run<H: Handler>(handler: H)` / `fn run<H>(handler: H) where H: Handler`.
  Keep the named generic only when the type must actually be referred to: it
  is used in more than one place, you need it via turbofish
  (`foo::<H>()`), you reference its associated types (`H::Item`), it appears
  in the return type, or the function is a trait-impl method whose signature
  must match the trait declaration. The named form is strictly more verbose
  for the single-use case, so default to `impl Trait` there.
- Lay out modules with the **`<module>.rs` + `<module>/` directory** form, not
  `<module>/mod.rs`. A module that has children lives in `foo.rs` alongside a
  `foo/` directory holding its submodules (`foo/bar.rs`), never in
  `foo/mod.rs`. The `mod.rs` style is discouraged: it scatters many identically
  named files across the tree and makes editor tabs ambiguous. The only place
  `mod.rs` is unavoidable is the crate root (`lib.rs` / `main.rs`), which are
  not `mod.rs` anyway. When you find an existing `mod.rs`, migrate it to the
  `<module>.rs` form as you touch it.
- In a Cargo **workspace**, put each member crate in its own directory **at the
  repository root** (`<repo>/<crate-name>/`), not nested under a `crates/` (or
  `packages/`, `libs/`, …) subdirectory. List members explicitly in the root
  `[workspace] members = [...]` rather than globbing a wrapper dir. The root
  `Cargo.toml` is a virtual manifest (`[workspace]` only, no `[package]`).
  When you find a `crates/`-style layout, flatten it to root-level crates as
  you touch it.
- Build CLIs with `clap` (derive API). Configuration must resolve in this
  order: CLI flags → environment variables → defaults. **Every** option
  must be settable via an environment variable: always give each `clap`
  argument an `env = "..."` attribute — there is no config knob that can
  only be passed on the command line.
- Prefer `default_value_t = <typed value>` over a stringly-typed
  `default_value = "..."` whenever the field's type is anything other than a
  `String`/`&str` — enums, integers, paths, durations, etc. `default_value_t`
  takes a real value of the field's type (compile-time checked, rendered via
  `Display`), so the default cannot drift out of sync with the type and a typo
  is a build error rather than a runtime parse failure. (A plain `String` flag
  may keep `default_value = "info"`.) A custom enum used as a default therefore
  needs a `Display` impl mirroring its `FromStr`, e.g.
  `#[arg(long, env = "...", default_value_t = Mode::Auto)]`.
- Use `tokio` as the async runtime.
- Apply the **Signal handling and graceful shutdown** rules from `CLAUDE.md`.
  Rust mechanics: enable tokio's `signal` feature and write one
  `shutdown_signal()` future that completes on `SIGTERM` **or** `SIGINT`, then
  drive shutdown from it:
  ```rust
  async fn shutdown_signal() {
      use tokio::signal::unix::{signal, SignalKind};
      let mut interrupt = signal(SignalKind::interrupt()).expect("SIGINT handler");
      let mut terminate = signal(SignalKind::terminate()).expect("SIGTERM handler");
      tokio::select! { _ = interrupt.recv() => {}, _ = terminate.recv() => {} }
  }
  ```
  Handle both via `SignalKind` (don't mix `ctrl_c()` in for `SIGINT` — keep the
  two consistent). The above is unix-only, which is the right default for a
  Linux-container target; only if the binary must also run on Windows, guard it
  with `#[cfg(unix)]` and fall back to `tokio::signal::ctrl_c()` under
  `#[cfg(not(unix))]`. For an `axum` server, pass it to
  `axum::serve(..).with_graceful_shutdown(shutdown_signal())`. For a worker loop,
  race it against the loop with `tokio::select!`. `tokio::signal::ctrl_c` alone is
  **not** enough — it only covers `SIGINT`, so a container stopped with `SIGTERM`
  would never drain.
- **Every HTTP server / API uses the same stack, always: `axum` + `aide` +
  Scalar — no exceptions.** Never expose a bare `axum::Router` for an API:
  build the router with `aide`'s `ApiRouter` (drop-in for `axum`), document
  every endpoint, and serve the generated OpenAPI document.
- Generate the OpenAPI document with **`aide`** (its `ApiRouter` drop-in for
  `axum`) and **`schemars`** (derive `JsonSchema` on every request/response
  DTO). Serve the spec at `/openapi.json` and an interactive **Scalar**
  reference at `/docs` (via `aide`'s `scalar` feature).
  Practical notes learned the hard way:
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
- Always set up structured logging/tracing with `tracing` and
  `tracing-subscriber`. Initialise the subscriber once at the start of
  `main`, configured with an `EnvFilter`. The filter directive must come
  from `clap` — a dedicated option (e.g. `--log-level` / `--log-filter`)
  carrying an `env = "RUST_LOG"` attribute — not read directly from the
  environment. Instrument code with `tracing` spans/events; never
  `println!` / `eprintln!` for diagnostics. Example:
  ```rust
  #[derive(clap::Parser)]
  struct Cli {
      /// `tracing` filter directive (e.g. `info`, `myapp=debug,axum=warn`)
      #[arg(long = "log-filter", env = "RUST_LOG", default_value = "info")]
      log_filter: String,
  }

  fn main() {
      let cli = Cli::parse();
      tracing_subscriber::fmt()
          .with_env_filter(tracing_subscriber::EnvFilter::new(&cli.log_filter))
          .init();
  }
  ```
- Apply the **Logging and observability** rules from `CLAUDE.md`. Rust
  mechanics: `debug!` (and `trace!` for very high-volume detail) via
  `tracing`, level controlled by `RUST_LOG` through the `clap`-parsed
  filter, structured fields (`debug!(%name, count, "…")`) — never string
  interpolation.
- Format with `rustfmt` and lint with `clippy` (`cargo clippy -- -D warnings`).
  Add local `cargo fmt --check` and `cargo clippy` hooks to
  `.pre-commit-config.yaml`.
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
- For database integration tests, run against a **real Postgres** (the
  project's `docker-compose` service) and isolate with **`#[sqlx::test]`** —
  it creates a fresh database per test, applies the migrations, and injects a
  `PgPool` (or `PgConnection`). Point `DATABASE_URL` at the compose Postgres
  when running the suite. Do **not** use `testcontainers`.
- When a crate embeds migrations with `sqlx::migrate!(...)`, **add a `build.rs`**
  that re-runs on migration changes. The macro embeds the migrations at compile
  time, so adding a new `.sql` file does not, on its own, make Cargo rebuild the
  crate — the macro keeps expanding to the stale set and tests fail with
  confusing "relation does not exist" errors against the just-added schema. The
  fix is one line:
  ```rust
  // build.rs
  fn main() {
      // Recompile (re-expanding sqlx::migrate!) whenever a migration changes.
      println!("cargo:rerun-if-changed=migrations");
  }
  ```
  Create this `build.rs` as soon as the crate calls `sqlx::migrate!`, not after
  the first stale-migration surprise.
- Use `mockall` for test doubles. Define collaborators as traits, annotate
  them with `#[cfg_attr(test, mockall::automock)]` (or `mock!` when you
  cannot own the trait), and inject the mock in unit tests. Keep production
  injection on static dispatch (generics / `impl Trait`); only the test
  wiring may fall back to a trait object if generics make the seam
  impractical. Add `mockall` under `[dev-dependencies]` via `cargo add
  --dev mockall`. `mockall` supports native async traits (Rust ≥ 1.75), so
  there is no need for `async-trait` to make a trait mockable — keep
  `#[cfg_attr(test, mockall::automock)]` *above* the trait definition.
- For async methods on a trait, use a native `async fn` or, when the
  returned future must be `Send` (e.g. it crosses a `tokio::spawn` or a
  controller runtime), the desugared form
  `fn f(&self, …) -> impl Future<Output = …> + Send`. Such traits are not
  object-safe, which is fine: inject them with generics (`T: Trait`), not
  `dyn Trait`, consistent with the static-dispatch rule above.
- When the project ships a `Dockerfile`, build it with **cargo-chef** —
  but **only inside the `Dockerfile`**. Install it there with
  `cargo install cargo-chef --locked` (`chef` → `planner`
  (`cargo chef prepare`) → `builder` (`cargo chef cook` then
  `cargo build --release --locked`)). The recipe normalises away the package
  version and other non-dependency `Cargo.toml` metadata, so the cooked
  dependency layer stays cached across version bumps and source-only changes.
  Never add `cargo-chef` to `Cargo.toml` (deps or dev-deps) and never invoke
  it in local development or CI outside the image build — it is purely a
  Docker layer-caching tool.

**Never:**

- Never default to `Box<dyn Trait>` / `&dyn Trait` when generics or
  `impl Trait` express the same thing with static dispatch.
- Never use a different async runtime (`async-std`, `smol`, …) or a
  different web framework when `tokio` + `axum` fit the need.
- Never use `testcontainers` (or other throwaway-container harnesses) for
  database tests. Use a real Postgres (the project's `docker-compose`) with
  `#[sqlx::test]` for per-test isolation.
- Never expose an HTTP API without `aide` + Scalar: no bare `axum::Router`
  for an API, no hand-written OpenAPI, no alternative docs UI. Every endpoint
  is documented and the spec is served at `/openapi.json` with Scalar at
  `/docs`.
- Never use `println!` / `eprintln!` (or ad-hoc `log` setup) for
  application diagnostics; route everything through `tracing`.
- Never add a `clap` option without an `env = "..."` attribute, and never
  build the `EnvFilter` from `EnvFilter::from_env` / `from_default_env`
  or a direct `std::env` read — the directive must flow through the
  `clap`-parsed value.
- Never leave `clippy` warnings unaddressed. If a lint must be allowed,
  add a scoped `#[allow(...)]` with a justification comment.
- Never hand-roll mock structs, fakes, or stubs for a trait when
  `mockall` can generate them, and never pull in another mocking crate
  (`mockers`, `faux`, …) when `mockall` fits.
- Never hand-roll input validation (bespoke `validate()` methods returning
  `Result<(), String>`, ad-hoc field checks scattered through handlers)
  when the `validator` derive can express it, and never pull in another
  validation crate when `validator` fits.
- Never reach for the `async-trait` crate. Use native `async fn` /
  `-> impl Future<Output = …> (+ Send)` in traits and generic injection
  instead. The only exception is an external trait you do not own that is
  itself defined with `#[async_trait]`.
