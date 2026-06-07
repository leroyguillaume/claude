---
name: yaml-conventions
description: YAML formatting conventions (block style only, no flow style).
  TRIGGER when: editing or creating any `.yaml`/`.yml` file (manifests, Helm
  charts/values, GitHub Actions workflows, compose files, config); writing a
  YAML snippet inside docs or a `README.md`; user asks about YAML style, flow
  vs block style, or inline collections in this repo.
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
