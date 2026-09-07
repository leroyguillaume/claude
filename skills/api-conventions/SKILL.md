---
name: api-conventions
description: >-
  HTTP/RPC API conventions (dedicated DTOs, no domain models on the
  wire, camelCase JSON, FK naming, tagged operations, mandatory pagination of
  list endpoints, the OpenAPI document at `/openapi.json` rendered by Scalar
  at `/docs`). Applies to any HTTP/RPC surface in any language or framework.
  TRIGGER when: editing or creating request/response handlers, routes,
  controllers, or DTO/schema types; adding or changing an HTTP/RPC endpoint;
  returning a collection/list from an endpoint or a repository that backs one;
  designing a JSON body, query/path params, or an OpenAPI spec; wiring a docs
  UI; user asks about API contracts, serialisation, DTOs vs domain models,
  field casing, pagination, endpoint grouping, or where the docs are served.
  SKIP when: the work touches no request/response surface (pure CLI, library,
  data layer with no wire boundary) and the user isn't asking about API design.
  For the URL and method design itself — resource naming, REST verbs, status
  codes — load `rest-conventions` alongside this one.
---

# API conventions

Applies to every HTTP/RPC surface, in any language or framework. The language
skills restate the mechanics (which validation crate, which serde attribute)
where they need to be concrete.

This skill owns what goes **in** the messages. `rest-conventions` owns the
**URLs and methods** — the path names a resource, the method is the verb, and
no endpoint is called `/list` or `/update`. Both apply to every HTTP endpoint.

- **Never bind a domain, entity, or persistence model directly to a request
  or response body.** Domain / ORM / database structs stay behind the
  boundary; they must not be (de)serialised at the wire.
- For every endpoint, define **dedicated DTOs named after the operation** —
  `CreateXRequest` / `UpdateXRequest` for inputs and `XResponse` for outputs
  (using the language's idiomatic casing). One DTO per request and per
  response; do not reuse a domain type "because the fields happen to match",
  and do not share one DTO across create and update.
- **Validate at the DTO layer** (e.g. the `validator` crate in Rust, Pydantic
  in Python) and **convert explicitly** between DTOs and domain models
  (`From`/`Into`, a mapper, etc.). A handler's job is exactly: deserialise the
  request DTO → validate → map to a domain model → call the domain/repository
  layer → map the result into a response DTO.
- Prefer to make the rule unbreakable by construction: keep the
  (de)serialisation capability off the domain types themselves (e.g. do not
  derive `Serialize`/`Deserialize` on entities) so binding one to the wire
  fails to compile.
- This keeps the wire contract decoupled from internal models: renaming a
  column or restructuring an entity never silently changes the public API.
- **All JSON body fields are `camelCase`**, regardless of the language's
  native casing. Apply it at the serialisation layer, not by renaming each
  field: in Rust put `#[serde(rename_all = "camelCase")]` on every
  request/response DTO (`schemars` honours it, so the OpenAPI schema matches
  the wire). Path and query parameters keep the exact name of their URL
  placeholder (do not camelCase a `{job_id}` segment).
- **Name foreign-key fields consistently as `<entity>_id`** (→ `<entity>Id`
  on the wire): `creator_id`, `game_id` — never a mix like `created_by`
  alongside `game_id`. The referenced entity's own identifier stays `id`.
  Pick the suffix convention once and apply it to every reference field.
- **Group endpoints into named categories** so the generated reference is
  navigable: tag every operation (OpenAPI `tag` / the framework's equivalent)
  and declare the tags up front with a description and a deliberate order
  (e.g. `Authentication`, then the main resources). No operation ships
  untagged.
- **Serve the OpenAPI document from the application itself, at
  `/openapi.json`.** It is generated from the code by the framework (`aide` in
  Rust, FastAPI's own generator in Python, …), never hand-written, and no copy
  is committed to the repository — a generated file that can only ever be a
  stale duplicate of what the process already publishes is not worth the upkeep.
- **Render that document with Scalar at `/docs`, and with nothing else.** The
  path and the tool are both fixed, in every language and framework: a reader
  who knows one of our APIs knows where the reference is on all of them.
  Whatever documentation UI the framework bundles gets switched off so it cannot
  drift from Scalar or squat the path — in FastAPI that is `docs_url=None` *and*
  `redoc_url=None` on the application, then a route of your own on `/docs`.
- **Load Scalar from its CDN**
  (`https://cdn.jsdelivr.net/npm/@scalar/api-reference`), not from a build
  vendored into the service (`aide`'s bundled Scalar in particular renders with
  broken CSS). The trade-off is that `/docs` needs egress **from the reader's
  browser** — the service itself never calls out for it, and `/openapi.json`
  answers regardless — which is the right side of the bargain for a docs page.
- **`/docs` is a page, not an operation: keep it out of the document** (in
  FastAPI, `include_in_schema=False`), so it never shows up in a generated
  client or in the tool set an MCP layer derives from the spec.
- **Always paginate list endpoints — never return an unbounded collection.**
  Any endpoint that returns a collection takes pagination parameters and caps
  how much it returns. The repository/data-layer method that backs it must
  likewise never materialise the whole table in memory: it either takes a limit
  **or returns a stream** that the boundary consumes (e.g. `sqlx`'s `.fetch()`),
  applying the page size as it goes. Pagination of the *wire contract* is
  non-negotiable regardless of which the data layer uses. Use **offset/limit
  pagination** on the wire:
  - Query params **`page`** (1-based) and **`perPage`** (camelCase on the
    wire). The boundary maps them to `limit = perPage`,
    `offset = (page - 1) * perPage` for the data layer.
  - **Enforce a default and a hard maximum `perPage`** (e.g. default 50,
    max 100): clamp/validate at the DTO layer so a client can never request an
    unbounded page. Missing params fall back to the defaults.
  - Return a **paginated envelope**, not a bare array:
    `{ "items": [...], "page": 1, "perPage": 50, "total": 1234 }` (`total`
    being the unfiltered row count) so clients can compute the page count.
  - Offset/limit is the default; reach for cursor/keyset pagination only when
    a specific endpoint has deep-pagination or stable-ordering needs that
    offset can't meet, and say why.
