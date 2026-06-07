---
name: sql-conventions
description: SQL linting/formatting conventions (always sqlfluff).
  TRIGGER when: creating or editing a `.sql` file (queries, migrations, seeds);
  adding SQL to a repo; setting up pre-commit for a project that contains SQL;
  user asks about SQL linting/formatting or sqlfluff.
  SKIP when: no SQL is present or being added and the user isn't asking about
  SQL tooling.
---

# SQL conventions

**Always lint SQL with [`sqlfluff`](https://sqlfluff.com/).** Any repo that
contains `.sql` files must have the sqlfluff pre-commit hook. Add it to
`.pre-commit-config.yaml`, pinned to an explicit rev:

```yaml
- repo: https://github.com/sqlfluff/sqlfluff
  rev: 4.2.2
  hooks:
    - id: sqlfluff-lint
```

- **Lint every `.sql` file**, not just some — query files *and* migrations
  (and seeds, fixtures, …). The hook matches `\.sql$`, so this is automatic.
- **Add a `.sqlfluff` at the repo root** with at least the dialect and a raw
  templater (plain SQL, no Jinja/dbt):

  ```ini
  [sqlfluff]
  dialect = postgres
  templater = raw
  max_line_length = 100
  ```

  Set `dialect` to the project's actual database.

- **Follow sqlfluff's style, don't fight it.** Reformat the SQL to satisfy the
  rules rather than disabling them. In practice that means: single spaces (no
  column alignment in `CREATE TABLE` — sqlfluff removed the alignment rule on
  purpose), one `SELECT` target per line when there is more than one, and
  consistent keyword casing.

- **Only `exclude_rules` for deliberate, justified cases**, with a comment
  saying why. The common one: using reserved-ish words as identifiers — e.g. a
  `user` table or a `role` column — trips `RF04` (keywords as identifiers) and
  `RF06` (unnecessary quoting, a false positive when the quotes are required).
  Exclude those, never silence spacing/layout rules to avoid reformatting:

  ```ini
  # We deliberately use the reserved words `user`/`role` as identifiers,
  # quoting `"user"` where Postgres requires it.
  exclude_rules = RF04, RF06
  ```

- **Prefer `sqlfluff fix`** to reformat in bulk when adopting it on an existing
  codebase, then commit the result; keep `sqlfluff-lint` as the gate.

## Externalising queries (when the language allows it)

Keep non-trivial SQL in `.sql` files rather than inline string literals, so the
linter sees it and the code stays readable. In Rust with `sqlx`, load them with
`include_str!("../queries/<entity>/<op>.sql")` — it stays a `&'static str` (so
sqlx 0.9's anti-injection guard is satisfied) and the compiler tracks each file
for rebuilds. See `rust-conventions` for the sqlx specifics.
