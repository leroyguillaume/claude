---
name: rest-conventions
description: >-
  REST resource design for any HTTP API — the path names a resource, the
  method is the verb. No `/list`, `/update`, `/getUser` or any other RPC verb
  in a URL. Covers collection and member URLs, method semantics, status codes,
  PUT vs PATCH, filters as query parameters, the escape hatch for operations
  that are not CRUD, error shape, idempotency and versioning.
  TRIGGER when: adding, renaming or reviewing an HTTP endpoint, route or
  controller; designing a URL, choosing a method or a status code; a path
  contains a verb, a `?action=`, or reads like a function call; modelling an
  operation that is not obviously create/read/update/delete; writing an
  OpenAPI document; the user asks about REST, endpoint naming or resource
  design.
  SKIP when: the surface is deliberately not REST (gRPC, GraphQL, JSON-RPC, a
  webhook receiver, a standard-mandated endpoint), or no HTTP interface is
  being designed. Load `api-conventions` alongside for the payload contract.
---

# REST conventions

`api-conventions` owns what goes **in** the messages. This owns what the
**URLs and methods** are. Both apply to every HTTP endpoint.

## The one rule everything else follows from

**The path names a resource. The method is the verb.**

A verb in a URL means the method has been reduced to a transport and the API
is RPC wearing REST's clothes. It is the single most common defect in a
hand-rolled HTTP surface, and it compounds: once `/team/update` exists,
`/team/update-budget` and `/team/update-members` follow within the month.

| Never | Always |
| --- | --- |
| `GET /getUser?id=7` | `GET /users/7` |
| `GET /users/list`, `GET /listUsers` | `GET /users` |
| `POST /users/create`, `POST /createUser` | `POST /users` |
| `POST /users/update`, `POST /updateUser` | `PUT` or `PATCH /users/7` |
| `POST /users/delete`, `GET /deleteUser?id=7` | `DELETE /users/7` |
| `GET /users/getByEmail?email=…` | `GET /users?email=…` |
| `GET /users/active`, `GET /users/findActive` | `GET /users?status=active` |
| `POST /api?action=updateUser` | `PATCH /users/7` |
| `GET /teams/7/getMembers` | `GET /teams/7/members` |

The test: **read the URL out loud with no method.** If it still describes an
action, it is wrong. `/users/7` is a thing; `/getUser` is an instruction.

## Two shapes of URL, and only two

- **A collection** — `/teams`. Plural noun.
- **A member** — `/teams/{teamId}`. The collection plus one identifier.

Everything else is one of those two hanging off another:
`/teams/{teamId}/members` is a collection, `/teams/{teamId}/members/{userId}`
is a member of it.

- **Plural nouns, always.** `/users`, not `/user` — even when the collection
  usually holds one thing. Mixing `/user/7` and `/teams/3` in one API is a
  papercut on every call site forever.
- **`kebab-case` for multi-word segments**: `/billing-entities`, never
  `/billingEntities` or `/billing_entities`. (Body fields are `camelCase` — see
  `api-conventions` — the two casings are deliberate and unrelated.)
- **No trailing slash, no file extension.** `/teams`, not `/teams/` or
  `/teams.json`. Content type is negotiated with headers.
- **Stop at two levels of nesting.** `/teams/{id}/members` is fine;
  `/orgs/{id}/teams/{id}/members/{id}/keys` is a URL nobody can build. Past
  two, make the deep thing a top-level collection and filter it:
  `/keys?teamId=…`.
- **Identifiers are opaque.** A client must never have to parse one, and the
  server must never make the format part of the contract.

## Methods

| Method | Means | Safe | Idempotent | Typical success |
| --- | --- | --- | --- | --- |
| `GET` | Read. Never changes state — not "usually", never. | yes | yes | `200`, `404` |
| `POST` | Create in a collection, or a non-idempotent operation | no | no | `201` + `Location`, `202` |
| `PUT` | Replace the member with the body, wholesale | no | yes | `200` / `204`, `201` if it created |
| `PATCH` | Partial modification | no | no¹ | `200` / `204` |
| `DELETE` | Remove the member | no | yes | `204`, `404` |

¹ A PATCH can be made idempotent, but nothing guarantees it — do not rely on
it.

**`GET` never has side effects and never takes a body.** A read that mutates
breaks every cache, proxy, retry and prefetch between client and server.

**`PUT` is a full statement of desired state, not a patch.** An absent field
means *unset*, not *leave alone*. That is what makes it idempotent, and
idempotence is what makes a client's retry safe — which is usually worth more
than the bytes PATCH saves. **Prefer `PUT` whenever the client can reasonably
send the whole resource**, and reach for `PATCH` when it genuinely cannot
(a large resource, a field-level permission split, a concurrent-editor
problem). If you ship `PATCH`, say in the docs which fields it accepts and
what omitting one means.

**`POST` to the collection, never to the member**, for creation: `POST /teams`
creates, `POST /teams/7` is meaningless. When the client owns the identifier,
`PUT /teams/{id}` is the create — and it is the better shape, because the
retry is free.

## Status codes

Use the small set that carries information, and use it accurately:

- **`200`** read or update succeeded, body attached · **`201`** created, with a
  `Location` header pointing at the new member · **`202`** accepted, work
  happens later (return something the client can poll) · **`204`** succeeded,
  deliberately no body.
- **`400`** malformed · **`401`** not authenticated · **`403`** authenticated,
  not allowed · **`404`** no such resource (also the right answer for "exists
  but you may not know that") · **`409`** conflict with current state ·
  **`422`** well-formed but semantically wrong — *this is the one that tells a
  client to stop retrying* · **`429`** rate limited, with `Retry-After`.
- **`5xx`** the server failed. **`502`/`504`** specifically when a dependency
  did, which is the difference between "your request is wrong" and "try again".

**Never return `200` with an error inside.** `{"success": false}` under a `200`
defeats every generic client, every retry policy and every dashboard, and it is
the reason somebody eventually writes a wrapper that greps the body. The status
code is part of the contract, not decoration.

**Distinguish "no" from "not now".** A permanent refusal (`4xx`, minus `408`,
`425`, `429`) and a transient failure (`5xx`, timeouts) are read by different
retry logic, and conflating them either loops a client forever or drops work on
the floor.

## Filtering, sorting, searching, pagination

All of it is **query parameters on the collection**, never a new path.

```
GET /teams?status=active&gbu=DIS&sort=-createdAt&page=2&perPage=50
```

- Filters are named after the field they filter on.
- Sorting is one `sort` parameter; prefix with `-` for descending.
- **Pagination is mandatory on every collection** — the envelope and the
  `page`/`perPage` contract live in `api-conventions`; do not restate them,
  and do not invent a second scheme.
- A search that is genuinely more than filters (full-text, a query language)
  still lives on the collection: `GET /teams?q=…`.

## Actions that are genuinely not CRUD

The honest part. Some operations are verbs — cancel an order, rotate a key,
block a team, retry a job, send an invitation — and forcing them into
create/read/update/delete produces a worse API than admitting it. Three
answers, in order of preference:

**1. The action changes a state — model the state.** Usually the best fix, and
usually available.

```
PUT /orders/{orderId}/status      {"status": "cancelled"}
PUT /teams/{teamId}/blocked       true
```

**2. The action produces a record — model the record.** Rotations, retries,
invitations and refunds are things that happened, with a time and an author,
and are usually worth being able to list afterwards.

```
POST /keys/{keyId}/rotations
POST /jobs/{jobId}/retries
POST /invitations                 {"teamId": "…", "email": "…"}
```

**3. Only when neither fits, a marked action endpoint** — a `POST` on the
member, with the action as the last segment, and a note in the docs saying why
it is not a resource:

```
POST /orders/{orderId}/cancel
```

This is a considered exception, not the default. If a design produces more than
one or two of these, the resources are modelled wrong. And it never applies to
something that is plainly CRUD: `POST /users/create` has no excuse.

## Errors, idempotency, versioning

**One error shape for the whole API**, on every failure, ideally
`application/problem+json` (RFC 9457): a stable machine-readable `type` or
code, a human `title`/`detail`, and the field paths when it is a validation
failure. A client must be able to write one error handler.

**`PUT` and `DELETE` are idempotent by construction — keep them that way.**
`DELETE` on something already gone is a success (`204`) or a `404`, never a
`409`. For a `POST` that a client must be able to retry safely, accept an
`Idempotency-Key` header and honour it.

**Version in the path from the first endpoint**: `/v1/teams`. It costs four
characters now and is impossible to retrofit later. Within a version, only
additive changes: new optional fields, new endpoints. Removing a field,
renaming one, tightening validation or changing a status code is a new version.
Clients must ignore unknown fields, and the docs must say so.

**Never:**

- Never put a verb, an action or a function name in a path.
- Never use `GET` for anything that changes state, or give it a body.
- Never return `200` with a failure in the body.
- Never mix singular and plural collection names in one API.
- Never return an unbounded collection.
- Never encode a filter as a path segment (`/users/active`).
- Never ship an unversioned public API.
- Never make an identifier's format part of the contract.
