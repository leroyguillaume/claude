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
- Diagnostic verbosity is controlled **only by the log level** (env var or
  config understood by the logging framework), never by a bespoke
  `--verbose`-style flag that gates whole code paths.
- Always log with **structured fields/key-values**, never by interpolating
  values into the message string. One log call should change what the reader
  knows; no noise, no secrets.
- Use the language's standard structured logging library, configured once at
  process start; never `print`/`println`/`echo`/`console.log` for
  diagnostics.
