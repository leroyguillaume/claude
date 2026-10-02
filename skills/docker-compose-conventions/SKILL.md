---
name: docker-compose-conventions
description: >-
  Docker Compose file naming.
  TRIGGER when: creating or editing a Compose file
  (`docker-compose.yaml`/`.yml`, `compose.yaml`/`.yml`); adding a Compose
  stack; user asks how to name a compose file.
  SKIP when: no Compose file is involved.
---

# Docker Compose conventions

- **Name the file `docker-compose.yaml`.** Always use this exact name, with the
  `.yaml` extension (not `.yml`), and not the shorter `compose.yaml` /
  `compose.yml` form. Compose discovers all of these automatically, so the
  choice is about consistency: every Compose file across every project carries
  the same recognisable name.
- If a repo already has a `compose.yaml`, `compose.yml`, or `docker-compose.yml`,
  rename it to `docker-compose.yaml` rather than leaving the variant in place.
- YAML inside the file follows `yaml-conventions`.
