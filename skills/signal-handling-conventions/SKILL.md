---
name: signal-handling-conventions
description: >-
  Signals and graceful shutdown for long-running processes.
  TRIGGER when: writing or editing a `main`/entrypoint, an HTTP or RPC server,
  a worker, a queue consumer or a daemon loop; wiring shutdown, signal
  handlers or drain logic; user asks about SIGTERM, SIGINT or graceful
  shutdown.
  SKIP when: a short-lived one-shot (CLI, library, script).
---

# Signal handling and graceful shutdown

Applies to every long-running process (servers, workers, daemons) in any
language or runtime. The language skills restate the mechanics (which signal
API, how to wire the shutdown future) where they need to be concrete.

- **Handle both `SIGTERM` and `SIGINT`** and shut down gracefully on either.
  `SIGTERM` is what an orchestrator (Docker, Kubernetes, systemd, a process
  manager) sends to stop a process; `SIGINT` is Ctrl-C in a terminal. A process
  that ignores `SIGTERM` is killed with `SIGKILL` after the grace period
  (Docker's default is 10s), losing in-flight work.
- **`SIGKILL` (and `SIGSTOP`) cannot be caught** — do not try. The whole point
  of handling `SIGTERM` is to finish cleanly *before* the orchestrator escalates
  to `SIGKILL`.
- A graceful shutdown **stops accepting new work** (close listeners, stop
  pulling from the queue) and **lets in-flight work drain** within the grace
  period, then exits **0**. Release external resources (connections, locks,
  temp files) on the way out.
- For pull-based workers, make interruption safe rather than relying on a clean
  drain: the unit of work should be idempotent / re-runnable so that a process
  killed mid-task is simply retried (e.g. a job left "processing" is requeued by
  a reaper). Cooperative shutdown then reduces wasted work; it is not the only
  thing standing between you and corruption.
