---
name: docker-compose-conventions
description: Docker Compose conventions (file naming).
  TRIGGER when: creating or editing a Docker Compose file (`docker-compose.yaml`,
  `docker-compose.yml`, `compose.yaml`, `compose.yml`); adding a Compose stack
  to a repo; user asks about Compose file naming or how to name a compose file
  in this repo.
  SKIP when: no Compose file is being created or edited and the user isn't
  asking about Compose file naming.
---

# Docker Compose conventions

- **Name the file `docker-compose.yaml`.** Always use this exact name, with the
  `.yaml` extension (not `.yml`), and not the shorter `compose.yaml` /
  `compose.yml` form. Compose discovers all of these automatically, so the
  choice is about consistency: every Compose file across every project carries
  the same recognisable name.
- If a repo already has a `compose.yaml`, `compose.yml`, or `docker-compose.yml`,
  rename it to `docker-compose.yaml` rather than leaving the variant in place.
- YAML inside the file follows the `yaml-conventions` skill: block style only,
  no flow style, no inline arrays.
