---
name: api-boundary-conventions
description: HTTP/RPC request/response boundary conventions (dedicated DTOs,
  no domain models on the wire, camelCase JSON, FK naming, tagged operations).
  Applies to any HTTP/RPC surface in any language or framework.
  TRIGGER when: editing or creating request/response handlers, routes,
  controllers, or DTO/schema types; adding or changing an HTTP/RPC endpoint;
  designing a JSON body, query/path params, or an OpenAPI spec; user asks about
  API contracts, serialisation, DTOs vs domain models, field casing, or
  endpoint grouping in this repo.
  SKIP when: the work touches no request/response surface (pure CLI, library,
  data layer with no wire boundary) and the user isn't asking about API design.
---

# API request/response boundaries

Applies to every HTTP/RPC surface, in any language or framework. The language
skills restate the mechanics (which validation crate, which serde attribute)
where they need to be concrete.

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
