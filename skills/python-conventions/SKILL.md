---
name: python-conventions
description: Python project conventions (uv, ruff, typer, pydantic, Pylance).
  TRIGGER when: editing or creating `.py` files; touching `pyproject.toml`, `uv.lock`,
  or `.python-version`; adding/removing a Python dependency; setting up a Python
  CLI, config layer, or data model; user asks about Python tooling, deps, types,
  CLI args, env vars, or logging in this repo.
  SKIP when: pure Rust/Helm/Docker/CI work with no Python file touched and the
  user isn't asking about Python.
---

# Python conventions

**Always:**

- Name every variable, function, method, attribute, and **model field** in
  `snake_case` (PEP 8). This holds for Pydantic models too — never declare
  literal `camelCase` field names. When a model serialises to a wire format
  that wants `camelCase` (a Kubernetes CRD, a `camelCase` JSON API), keep the
  Python fields `snake_case` and let an alias bridge the gap: set
  `alias_generator=to_camel` + `populate_by_name=True` on the base model, so
  `endpoint_url` becomes `endpointUrl` on the wire while Python stays
  idiomatic. Serialise with `by_alias=True` (and accept either spelling on the
  way in). Leave ruff's `N815` (mixed-case class variable) **enabled** — it is
  the guard that catches a stray `camelCase` field; never add it to `ignore`.
- Use `pyproject.toml` as the single source of truth for metadata,
  dependencies, and tool configuration (`ruff`, `pytest`, etc.).
- Use `uv` for dependency and environment management: `uv init`, `uv add`,
  `uv sync`, `uv run`, `uv lock`. Commit `uv.lock`.
- Format and lint with `ruff` (`ruff format` + `ruff check --fix`).
  Configure in `pyproject.toml`.
- Add `astral-sh/ruff-pre-commit` to `.pre-commit-config.yaml` with both
  `ruff` and `ruff-format` hooks.
- Treat **Pylance** diagnostics (and any `pyright` output it surfaces) as
  blocking, on the same footing as `ruff` errors. Fix every reported
  error and warning before considering a change done. When Pylance and
  ruff disagree on a stylistic point, prefer the change that satisfies
  both; never silence one to keep the other happy.
- Build CLIs with `typer`. Configuration must resolve in this order:
  CLI flags → environment variables → defaults. Use `typer` option
  `envvar=...`, or `pydantic-settings` for richer config models.
- Declare `typer` parameters with `Annotated[T, typer.Option(...)] = default`,
  not `param: T = typer.Option(default, ...)`. The `Annotated` form keeps the
  default value in the standard Python position and is the form `typer`
  recommends. Example:
  ```python
  from typing import Annotated
  import typer

  def serve(
      port: Annotated[int, typer.Option(envvar="PORT", help="Listen port")] = 8080,
  ) -> None: ...
  ```
- Apply the **Logging and observability** rules from `CLAUDE.md`. Python
  mechanics: use the standard `logging` module (or `structlog` when the
  project already does), configured once at process start; level
  controlled by an env var (e.g. `LOG_LEVEL`) routed through the `typer` /
  `pydantic-settings` config layer. Log structured key-values
  (`logger.debug("fetched", extra={"url": url, "status": resp.status})`),
  never f-string interpolation of values into the message.
- Model structured data with an **explicit type**, never a bare `dict` /
  `tuple` threaded through the code as an ad-hoc record. As soon as a value
  has a known, fixed set of fields:
  - **First, reuse the canonical type if one already exists** in the
    standard library or a dependency you already have (e.g.
    `kubernetes.client.V1OwnerReference`, an SDK's request/response model,
    a protobuf/`dataclass` the API ships). Do not hand-roll a parallel
    model of something a depended-upon library already defines — convert
    at the edges with the library's own serializer
    (`ApiClient().sanitize_for_serialization`, `.model_dump()`, …).
  - Otherwise define one: a `pydantic.BaseModel` when it crosses an I/O,
    serialization, or API boundary (parsed from / rendered to JSON, YAML,
    a request, a manifest, …) — the default in a Pydantic codebase;
    a `@dataclass(frozen=True)` for an internal value object that never
    leaves the process; a `TypedDict` only when an external API hands you
    a `dict` you do not construct yourself and a model wrapper would be
    pure overhead.

  Reserve `dict[...]` / `Mapping` for genuinely dynamic maps whose keys are
  *data*, not field names. Construct the type at the boundary where the
  data enters and pass the typed object onward; do not pass the raw `dict`.

**Never:**

- Never use `pip`, `poetry`, `pipenv`, or `conda`.
- Never create a `setup.py`, `setup.cfg`, `requirements.txt`, `ruff.toml`,
  or `pytest.ini`. All config lives in `pyproject.toml`.
- Never hand-edit dependency files; use `uv add` / `uv remove`.
- Never read config via `os.environ.get(...)` scattered through the code;
  route everything through the `typer` / `pydantic-settings` layer.
- Never declare `typer` parameters with the legacy
  `param: T = typer.Option(default, ...)` form; use `Annotated` instead.
- Never silence a Pylance / `pyright` diagnostic with `# type: ignore`,
  `# pyright: ignore`, or `cast()` without a one-line comment explaining
  why the type checker is wrong and why the cast is safe. If you can fix
  the underlying type instead, do that.
- Never pass a `dict[str, Any]` (or a positional `tuple`) between functions
  as a stand-in for a record whose fields are known, and never annotate a
  parameter or return as a broad `dict` / `tuple` when the shape is fixed
  and knowable — define the type and use it.
- Never use `print()` for diagnostics; route everything through the
  configured logger.
