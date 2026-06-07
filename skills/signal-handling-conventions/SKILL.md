---
name: signal-handling-conventions
description: Signal handling and graceful shutdown conventions for long-running
  processes (SIGTERM/SIGINT, drain in-flight work, idempotent units of work).
  Applies to servers, workers, and daemons in any language or runtime.
  TRIGGER when: writing or editing a process entrypoint / `main`, an HTTP or
  RPC server, a background worker, a queue consumer, or any daemon loop;
  wiring shutdown, signal handlers, or drain logic; user asks about SIGTERM,
  SIGINT, graceful shutdown, drain, or interruption safety in this repo.
  SKIP when: the code is a short-lived one-shot (a CLI that runs and exits, a
  library, a script) with no long-running loop, and the user isn't asking
  about shutdown.
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
