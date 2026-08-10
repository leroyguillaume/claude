---
name: yaml-conventions
description: YAML formatting conventions (block style only, no flow style, no
  `---` opening a file).
  TRIGGER when: editing or creating any `.yaml`/`.yml` file (manifests, Helm
  charts/values, GitHub Actions workflows, compose files, config); writing a
  YAML snippet inside docs or a `README.md`; user asks about YAML style, flow
  vs block style, document start markers, or inline collections in this repo.
  SKIP when: no YAML is being written or edited and the user isn't asking about
  YAML formatting.
---

# YAML formatting

Applies everywhere YAML appears: manifests, Helm charts/values, GitHub Actions
workflows, docs, and example snippets in `README.md`.

- **Never use flow style (inline `{...}` / `[...]`) in YAML.** Always write
  block style, one key per line. For example, write

  ```yaml
  applications:
    kubeflow:
      enabled: true
  ```

  not `kubeflow: { enabled: true }`. The only acceptable inline form is an
  intentionally empty collection (`{}` / `[]`).

- **Never write inline arrays.** A sequence must use block style, one item per
  line with a leading `- `, even for a single element. Write

  ```yaml
  ports:
    - "11434:11434"
  command:
    - /bin/sh
    - -c
  ```

  not `ports: ["11434:11434"]` or `command: ["/bin/sh", "-c"]`. The only
  exception is an intentionally empty list (`[]`).

- **Never open a file with `---`.** The document start marker is optional in
  YAML, means nothing for a single-document file, and every tool reads the file
  identically with or without it. Start on the first key, or on the leading
  comment:

  ```yaml
  # Fixtures for the e2e suite.
  apiVersion: v1
  kind: Namespace
  ```

  not a bare `---` on line 1. The **separators between documents** in a
  genuinely multi-document file are a different thing — required syntax, keep
  them. Markdown/skill frontmatter delimiters are not YAML documents either;
  leave those alone.

Enforce all of the above with a `yamllint` hook (`document-start: present:
false`, `braces` / `brackets` `forbid: non-empty`) rather than by review — see
`pre-commit-conventions` for the hook and the config.
