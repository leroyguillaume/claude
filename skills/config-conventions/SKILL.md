---
name: config-conventions
description: >-
  Configuration surface in any language: env-var names, flags, config files,
  precedence, the log-level variable.
  TRIGGER when: reading an environment variable; defining CLI flags or
  options; adding a config file or a config layer, in any language; user asks
  how to name an env var or which setting wins.
  SKIP when: the change adds or reads no configuration.
---

# Configuration conventions

Applies to every language. The language skills (`python-conventions`,
`rust-conventions`) give the mechanics: which library holds the config layer
and how an option declares its variable.

## Precedence

Every setting resolves in one order, the first source that sets it winning:

**CLI flags → environment variables → config file → defaults.**

- **Every option is settable through an environment variable.** No knob is
  reachable by flag only: a container, a CI job or a systemd unit configures a
  process through its environment.
- **A config file is optional**, for a project with enough settings to warrant
  one. Its path is itself an option, flag and variable like any other
  (`--config-file`, `CONFIG_FILE` or `MYTOOL_CONFIG_FILE`), and what the file
  sets loses to the environment. Only structured data with no flat form (a
  list of targets, a map of rules) may live in the file alone.
- **Read configuration in one place**, the config layer, once at start-up,
  into a typed structure handed to the rest of the program. A variable read
  deep inside a module is missing from `--help`, from the docs and from the
  tests.

## Naming environment variables

The right name depends on **who owns the environment the process runs in**.

- **A process that owns its environment takes the bare, conventional name.**
  A service, daemon, worker or job in a container is handed an environment
  written for it and nothing else, so a prefix is pure noise: `BIND_ADDR`,
  `DB_MAX_CONNECTIONS`, `STORAGE_BACKEND` — never `MYAPP_BIND_ADDR`.
- **A CLI or tooling binary prefixes every variable with its own name**, in
  upper snake case: `MYTOOL_CONFIG_FILE`, `MYTOOL_FORCE`,
  `RIPGREP_CONFIG_PATH`. Its shell or CI job is shared with dozens of other
  tools, and its knobs are the generic words everybody uses — `FORCE`,
  `DRY_RUN`, `OFFLINE`, `CONFIG_FILE`, `TARGET`, `VERBOSE`, `DEBUG`. A
  leftover value is picked up in silence, and for a destructive flag the first
  symptom is the damage: a `FORCE=1` exported an hour ago for another tool
  turns a refusal to overwrite into an overwrite.
- **For a binary that is arguably both** (a server with a CLI entrypoint, a
  tool that also runs as a job), ask: *would a person plausibly have this
  variable set for another reason when they run it?* In a container, no —
  bare names. On a laptop or in a CI shell, yes — prefix.
- **Never read both the prefixed and the bare name.** The fallback keeps the
  very collision the prefix removes, and it fails silently. One name, read
  once.
- **Cross-tool standards keep their standard name, prefix or not**:
  `NO_COLOR`, `HTTP_PROXY` / `HTTPS_PROXY` / `NO_PROXY`, `SSL_CERT_FILE`,
  `XDG_*`, `DATABASE_URL` where it really is the standard, and an upstream's
  own variables (`OLLAMA_HOST`). Being shared is their whole point; never
  prefix or rename one.

## The log-level variable

- **`LOG_LEVEL`** sets the verbosity (`MYTOOL_LOG_LEVEL` for a CLI), with a
  `--log-level` flag beside it.
- **Rust names it `LOG_FILTER`** (`MYTOOL_LOG_FILTER`, `--log-filter`): it
  carries a `tracing` `EnvFilter` directive (`info,myapp=debug,hyper=warn`),
  not a level, and the name says what the value is.
- **A browser bundle takes `VITE_LOG_LEVEL`, at build time**: it has no flags
  and no runtime environment, and Vite exposes only `VITE_`-prefixed
  variables to client code. It is the one exception to the precedence above.
- **Never a language-named variable such as `RUST_LOG`**: the name describes
  the knob, not the language the binary is written in.

The log format variable and its default are in `logging-conventions`.

**Never:**

- Never add a scalar setting that only a flag, or only a config file, can set.
- Never read an environment variable outside the config layer.
- Never give a CLI's own variable a bare name, or a service's a prefixed one.
- Never fall back from one variable name to another.
