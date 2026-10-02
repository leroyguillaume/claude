---
name: rust-conventions
description: >-
  Rust projects: crate choices (clap, tokio, tracing, mockall), layout and
  toolchain.
  TRIGGER when: editing `.rs` files; touching `Cargo.toml`, `Cargo.lock`,
  `rust-toolchain*` or `.cargo/config.toml`; adding a Rust dependency; setting
  up a Rust CLI, server, async trait, mock or subscriber; a `cargo run`/`cargo
  test` needing env vars.
  SKIP when: no Rust is involved. Load `rust-http-conventions` alongside for
  HTTP.
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
  named files across the tree and makes editor tabs ambiguous. An existing
  `mod.rs` layout is migrated only on request or as a change of its own, never
  as a drive-by inside unrelated work.
- In a Cargo **workspace**, put each member crate in its own directory **at the
  repository root** (`<repo>/<crate-name>/`), not nested under a `crates/` (or
  `packages/`, `libs/`, …) subdirectory. List members explicitly in the root
  `[workspace] members = [...]` rather than globbing a wrapper dir. The root
  `Cargo.toml` is a virtual manifest (`[workspace]` only, no `[package]`).
  An existing `crates/`-style layout is flattened only on request or as a
  change of its own.
- Build CLIs with `clap` (derive API). Configuration must resolve in this
  order: CLI flags → environment variables → defaults. **Every** option
  must be settable via an environment variable: always give each `clap`
  argument an `env = "..."` attribute — there is no config knob that can
  only be passed on the command line.
- **Name the variable after who owns the environment.** A service in a
  container owns it and takes the bare name (`env = "BIND_ADDR"`); a CLI or
  tooling binary shares a shell with everything else, so it prefixes its own
  variables with its name (`env = "MYTOOL_FORCE"`). Read one name only, never
  a bare-name fallback, and keep cross-tool standards (`NO_COLOR`,
  `HTTP_PROXY`, `SSL_CERT_FILE`) as they are.
- Prefer `default_value_t = <typed value>` over a stringly-typed
  `default_value = "..."` whenever the field's type is anything other than a
  `String`/`&str` — enums, integers, paths, durations, etc. `default_value_t`
  takes a real value of the field's type (compile-time checked, rendered via
  `Display`), so the default cannot drift out of sync with the type and a typo
  is a build error rather than a runtime parse failure. (A plain `String` flag
  may keep `default_value = "info"`.) A custom enum used as a default therefore
  needs a `Display` impl mirroring its `FromStr`, e.g.
  `#[arg(long, env = "...", default_value_t = Mode::Auto)]`.
- **Give the development defaults a `.cargo/config.toml` with an `[env]`
  table**, committed at the repository root, as soon as a binary needs an
  environment variable to start. `cargo run` and `cargo test` then work from a
  fresh clone with nothing exported, and the
  `DATABASE_URL=… JWT_SECRET=… S3_BUCKET=… cargo run` incantation disappears
  from the README instead of being copy-pasted wrong.
  ```toml
  # .cargo/config.toml
  # Cargo sets these only for what it spawns (`cargo run`, `cargo test`), not
  # for ./target/debug/app run by hand or in a container.
  [env]
  DATABASE_URL = "postgres://app:app@localhost:5432/app"
  # Resolved against this file's parent directory, not the shell's cwd.
  MIGRATIONS_DIR = { value = "migrations", relative = true }
  ```
  Four rules keep it from becoming a liability:
  - **Never `force = true`.** Without it, a variable already present in the
    environment wins and the file stays a fallback; with it, CI's own
    `DATABASE_URL` and a container's real configuration are silently replaced
    by a development default. That single word is the difference between a
    convenience and a footgun.
  - **Only values that unlock the project's own throwaway stack** — the
    `docker-compose` services and nothing else. A credential that reaches a
    shared or production system never goes in a committed file, whatever the
    variable is called.
  - **Say in a comment that Cargo applies `[env]` only to processes it
    spawns.** `cargo run` and `cargo test` get the values; running
    `./target/debug/app` by hand, or the binary in a container, gets nothing.
    That is the first surprise, and it is cheaper to answer in the file than in
    a bug report.
  - **Keep it the one home for those values.** The README says the file exists
    and that the environment takes precedence; it does not restate the values.
- Use `tokio` as the async runtime.
- Apply `signal-handling-conventions`. Rust mechanics: enable tokio's
  `signal` feature and write one `shutdown_signal()` future that completes on
  `SIGTERM` **or** `SIGINT`, then drive shutdown from it:
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
  `#[cfg(not(unix))]`. A server hands it to its graceful-shutdown hook (see
  `rust-http-conventions`); a worker loop races it with `tokio::select!`.
  `tokio::signal::ctrl_c` alone is **not** enough — it only covers `SIGINT`,
  so a container stopped with `SIGTERM` would never drain.
- Any HTTP surface — framework, OpenAPI, input validation with `validator` —
  follows `rust-http-conventions`; load it before touching a handler, a router
  or a request/response DTO.
- Always set up structured logging/tracing with `tracing` and
  `tracing-subscriber`. Initialise the subscriber once at the start of
  `main`, configured with an `EnvFilter`. The filter directive must come
  from `clap` — a dedicated option (e.g. `--log-level` / `--log-filter`)
  carrying an `env = "LOG_FILTER"` attribute, or `<TOOL>_LOG_FILTER` when the
  binary is a CLI — not read directly from the environment. **Never
  `RUST_LOG`**: the variable name should describe the knob, not the language
  the binary happens to be written in, and `RUST_LOG` is also read by other
  crates' own `from_default_env()` machinery, which is exactly the
  direct-environment read this rule forbids. Document the directive syntax in
  the option's help so `--help` is self-sufficient. The log format is a
  `clap` option too (`LOG_FORMAT` / `<TOOL>_LOG_FORMAT`, `text` by default,
  `json` opt-in). **`tracing_subscriber::fmt()` writes to stdout by
  default**, which mixes logs into the program's result, so always point it
  at stderr. Example:
  ```rust
  #[derive(Clone, Copy, clap::ValueEnum)]
  enum LogFormat { Text, Json }

  #[derive(clap::Parser)]
  struct Cli {
      /// `tracing` filter directive (e.g. `info`, `myapp=debug,axum=warn`)
      ///
      /// Syntax: <https://docs.rs/tracing-subscriber/latest/tracing_subscriber/filter/struct.EnvFilter.html#directives>
      #[arg(long = "log-filter", env = "LOG_FILTER", default_value = "info")]
      log_filter: String,
      #[arg(long, env = "LOG_FORMAT", value_enum,
            default_value_t = LogFormat::Text)]
      log_format: LogFormat,
  }

  fn main() {
      let cli = Cli::parse();
      let fmt = tracing_subscriber::fmt()
          .with_env_filter(tracing_subscriber::EnvFilter::new(&cli.log_filter))
          .with_writer(std::io::stderr);
      match cli.log_format {
          LogFormat::Text => fmt.init(),
          LogFormat::Json => fmt.json().init(), // needs the `json` feature
      }
  }
  ```
- Apply `logging-conventions`. Rust mechanics: `debug!` (and `trace!` for
  very high-volume detail) via `tracing`, level controlled by the
  `clap`-parsed filter above, structured fields (`debug!(%name, count, "…")`)
  — never string interpolation, never `println!` / `eprintln!` for
  diagnostics.
- **Only the program's result goes to stdout; everything else goes to
  stderr.** `println!` is for what the program *produces* — the thing a caller
  would pipe into a file or another command. Error messages, usage hints and
  notes to whoever is watching go to `eprintln!`, so that `cmd > out.txt`
  keeps the output clean *and* the diagnostics visible. The split is by
  audience, not by severity: stdout is for the next program in the pipeline,
  stderr is for the person at the terminal.

  This does not loosen the logging rule — diagnostics about the program's own
  workings still go through `tracing` (writing to stderr, as above), never
  through either macro.
- Format with `rustfmt` and lint with `clippy` (`cargo clippy -- -D warnings`).
  Add local `cargo fmt --check` and `cargo clippy` hooks to
  `.pre-commit-config.yaml`.
- **Declare lints once, in the manifest** — never as `#![warn(...)]` attributes
  scattered across crate roots. In a workspace, the table lives in the root
  virtual manifest and every member opts in with `[lints] workspace = true`:
  ```toml
  # Cargo.toml (workspace root)
  [workspace.lints.rust]
  missing_docs = "warn"
  unsafe_code = "forbid"

  [workspace.lints.clippy]
  all = { level = "warn", priority = -1 }
  pedantic = { level = "warn", priority = -1 }
  ```
  ```toml
  # <crate>/Cargo.toml
  [lints]
  workspace = true
  ```
  **Lint *groups* must carry `priority = -1`.** Cargo turns each entry into a
  rustc flag and rustc applies "last flag wins", but **Cargo ignores the order
  the entries are written in** and sorts by `priority` instead. A group left at
  the default priority of 0 can therefore be emitted *after* an individual
  `allow` of one of its lints and silently re-enable it. `clippy::all` includes
  `lint_groups_priority`, which catches this and suggests the fix — do not
  ignore that warning.
- **Aim for an empty allow-list.** `pedantic` is worth keeping on: its noisy
  lints still force a decision, and its cast/float lints catch real bugs long
  after the code was written. When a lint fires, the default is to comply.
  Blanket `allow` entries in the manifest are a last resort and must carry a
  comment explaining what was traded away — a global `allow` hides a problem
  everywhere, whereas a scoped `#[allow(clippy::…)]` at the offending item,
  with a justification comment, documents it exactly where it matters. Prefer
  the scoped form every time. Beware of writing the allow-list *before* the
  code: allows added at bootstrap "because everyone disables those" are
  cargo-cult, and some will not even be in the group any more.
- **Pin the toolchain with a `rust-toolchain.toml`** at the repository root, on
  an exact patch version, as soon as the project lints with `pedantic` and
  fails the build on warnings. Without a pin, a clippy release turns CI red on
  code nobody touched; with one, a toolchain bump is a reviewable diff.
  ```toml
  [toolchain]
  channel = "1.97.1"
  components = ["rustfmt", "clippy"]
  profile = "minimal"
  ```
  This pin is **not** the MSRV. `rust-version` in `Cargo.toml` is what
  consumers must have and should stay as low as the code allows; the toolchain
  file is what contributors and CI build with and should stay current. Never
  collapse the two.
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
      println!("cargo::rerun-if-changed=build.rs");
      println!("cargo::rerun-if-changed=migrations");
  }
  ```
  Create this `build.rs` as soon as the crate calls `sqlx::migrate!`, not after
  the first stale-migration surprise.
- **This is specific to macros that read files themselves** (`sqlx::migrate!`
  and similar proc macros). `include_str!` / `include_bytes!` need no
  `build.rs`: `rustc` records the included file in its dep-info, and Cargo
  rebuilds when it changes. Whenever a `build.rs` exists, emit
  `rerun-if-changed` for `build.rs` itself and every path it watches: a build
  script that emits **no** `rerun-if-changed` at all is re-run on *any* file
  change in the package. The `cargo::` form needs Rust ≥ 1.77; a crate whose
  `rust-version` is lower keeps the single-colon `cargo:` form.
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
- Never use an async runtime other than `tokio` (`async-std`, `smol`, …).
- Never set `force = true` in a `.cargo/config.toml` `[env]` table, and never
  put a credential there that reaches anything beyond the project's own
  development stack. Development defaults must lose to a real environment.
- Never front a documented `cargo run` / `cargo test` with a wall of
  `VAR=value` assignments when `.cargo/config.toml` can carry them.
- Never use `testcontainers` (or other throwaway-container harnesses) for
  database tests. Use a real Postgres (the project's `docker-compose`) with
  `#[sqlx::test]` for per-test isolation.
- Never use `println!` / `eprintln!` (or ad-hoc `log` setup) for
  application diagnostics; route everything through `tracing`.
- Never add a `clap` option without an `env = "..."` attribute, never give a
  CLI's own option a bare unprefixed variable name, and never build the
  `EnvFilter` from `EnvFilter::from_env` / `from_default_env` or a direct
  `std::env` read — the directive must flow through the `clap`-parsed value.
- Never leave `clippy` warnings unaddressed. If a lint must be allowed,
  add a scoped `#[allow(...)]` with a justification comment.
- Never hand-roll mock structs, fakes, or stubs for a trait when
  `mockall` can generate them, and never pull in another mocking crate
  (`mockers`, `faux`, …) when `mockall` fits.
- Never reach for the `async-trait` crate. Use native `async fn` /
  `-> impl Future<Output = …> (+ Send)` in traits and generic injection
  instead. The only exception is an external trait you do not own that is
  itself defined with `#[async_trait]`.
