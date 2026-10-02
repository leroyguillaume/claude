---
name: logging-conventions
description: >-
  Logging in any language: debug logs, structured fields, levels.
  TRIGGER when: writing code that does I/O or external calls, branches
  non-trivially or runs long; configuring a logging library or subscriber;
  replacing `print`/`println`/`echo`/`console.log`; user asks about logging or
  observability.
  SKIP when: the change adds no behaviour worth logging (formatting, comments,
  config).
---

# Logging and observability

Applies to every language and runtime. The language skills restate the
mechanics (library, level names, env var) where they need to be made concrete.

- Emit **debug-level** logs liberally wherever they help diagnose a problem
  after the fact: around every external / I/O call (log its inputs and its
  outcome), at each non-trivial decision branch, and at the boundaries of
  long or multi-step operations. The bar: a misbehaving program can be
  understood from its debug output alone, without adding logging and
  re-running.
- Reserve **info** for state transitions worth seeing at the default level;
  use **warn / error** for failures (with the cause).
- Diagnostic verbosity is controlled **only by the log level**, set through
  the application's config layer (flag, env var, config file), never by a
  bespoke `--verbose`-style flag that gates whole code paths.
- Always log with **structured fields/key-values**, never by interpolating
  values into the message string. One log call should change what the reader
  knows; no noise, no secrets.
- Use the language's standard structured logging library, configured once at
  process start; never `print`/`println`/`echo`/`console.log` for
  diagnostics.

## Log format — default to `text`, not `json`

- **Default the log format to `text`, never `json`.** A human reading
  `kubectl logs`, `docker logs` or a terminal parses key=value far more easily
  than one JSON object per line. JSON is opt-in, for deployments whose log
  pipeline parses it.
- Drive it off `LOG_FORMAT` (`<TOOL>_LOG_FORMAT` for a CLI; `text` | `json`,
  default `text`) and keep the **binary's default and every deployment
  default in sync** — a Helm chart's `logging.format` value that disagrees
  with what the binary does on its own is a bug.
