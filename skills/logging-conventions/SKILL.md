---
name: logging-conventions
description: Logging and observability conventions (liberal debug logs,
  structured key-value fields, level-controlled verbosity, standard logging
  library). Applies to every language and runtime.
  TRIGGER when: writing or editing code that does I/O or external calls, has
  non-trivial decision branches, or runs long/multi-step operations; setting up
  or configuring a logging library / subscriber; adding diagnostics or replacing
  `print`/`println`/`echo`/`console.log`; user asks about logging, log levels,
  structured logging, verbosity, or observability in this repo.
  SKIP when: the change is trivial and adds no behaviour worth logging (pure
  formatting, comments, config-only edits) and the user isn't asking about
  logging.
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
