---
name: rust-build-conventions
description: >-
  Rust build and test infrastructure: toolchain pin, sqlx database tests,
  `build.rs`, cargo-chef.
  TRIGGER when: scaffolding a Rust project; pinning the Rust toolchain; a
  `rust-toolchain.toml` (or `rust-toolchain`) in the repo; editing a
  `build.rs`; calling `sqlx::migrate!` or writing a
  `#[sqlx::test]`; "relation does not exist" after adding a migration;
  building a Rust `Dockerfile` or touching `cargo chef`; CI red after a clippy
  release.
  SKIP when: no such file or test is involved (`rust-conventions`). Load
  `rust-conventions` alongside.
---

# Rust build and test conventions

**Always:**

- **Pin the toolchain in `mise.toml`** (`mise-conventions`), on an exact
  patch version, never in a `rust-toolchain.toml`: an existing one moves into
  `mise.toml` and is deleted. Without a pin, a clippy release turns CI red on
  code nobody touched; with one, a toolchain bump is a reviewable diff.
  ```toml
  [tools]
  rust = { version = "<current stable release>", components = ["rustfmt", "clippy"], profile = "minimal" }
  ```
  Resolve `<current stable release>` when you write the file, from `mise
  latest rust` or <https://releases.rs>, never from memory.
  This pin is **not** the MSRV. `rust-version` in `Cargo.toml` is what
  consumers must have and should stay as low as the code allows; the toolchain
  pin is what contributors and CI build with and should stay current. Never
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
- When the project ships a `Dockerfile`, build it with **cargo-chef** —
  but **only inside the `Dockerfile`**. Install it there with
  `cargo install cargo-chef --locked --version "${CARGO_CHEF_VERSION}"`, the
  version in an `ARG CARGO_CHEF_VERSION=<latest release>` resolved when you
  write it, preceded by `# renovate: datasource=crate depName=cargo-chef` for
  the Renovate custom manager that keeps it current
  (`dependency-update-conventions`). The `ARG` sits at the top of the
  `Dockerfile` with the other version knobs (`docker-conventions`) and is
  redeclared, bare, in the `chef` stage: an `ARG` before `FROM` is not visible
  inside a stage. Stage it `chef` → `planner` (`cargo chef prepare`) →
  `builder` (`cargo chef cook` then `cargo build --release --locked`). The
  recipe normalises away the package version and other non-dependency
  `Cargo.toml` metadata, so the cooked
  dependency layer stays cached across version bumps and source-only changes.
  Never add `cargo-chef` to `Cargo.toml` (deps or dev-deps) and never invoke
  it in local development or CI outside the image build — it is purely a
  Docker layer-caching tool.

**Never:**

- Never use `testcontainers` (or other throwaway-container harnesses) for
  database tests. Use a real Postgres (the project's `docker-compose`) with
  `#[sqlx::test]` for per-test isolation.
