---
name: docker-conventions
description: Dockerfile conventions (FHS paths, non-root USER, hadolint,
  .dockerignore).
  TRIGGER when: editing or creating a `Dockerfile`, `Containerfile`,
  `.dockerignore`, or `docker-compose.yaml`/`compose.yaml`; user asks about
  container build paths, non-root users, or hadolint in this repo.
  SKIP when: pure Python/Rust/Helm/CI work with no Dockerfile touched and the
  user isn't asking about container builds.
---

# Docker conventions

**Always:**

- Create a `.dockerignore` file to exclude unnecessary files from the build
  context (`.git/`, `node_modules/`, `*.log`, `README.md`, etc.).
- Follow Linux (FHS) path conventions, with `<appname>` the project name:
  - **Build** in `/usr/local/src/<appname>` (the builder stage `WORKDIR`).
  - **Binary** installed to `/usr/local/bin/` (on `PATH`).
  - **Config**, if the app has any, under `/etc/<appname>/`.
  - Any mutable state under `/var/lib/<appname>/`.
- Create a dedicated non-root user and group **named after the app** (use a
  short, recognisable name if the project name is long or not a valid Linux
  username), with **UID 1000 and GID 1000**, `chown` the app-owned paths, and
  end the `Dockerfile` with a `USER` directive. Example (app `myapp`):
  ```dockerfile
  # builder stage
  WORKDIR /usr/local/src/myapp
  # ... build, producing /usr/local/src/myapp/target/release/myapp ...

  # runtime stage
  RUN groupadd --system --gid 1000 myapp \
   && useradd  --system --uid 1000 --gid myapp \
        --home /etc/myapp --shell /usr/sbin/nologin myapp
  COPY --from=builder --chown=myapp:myapp \
       /usr/local/src/myapp/target/release/myapp /usr/local/bin/myapp
  USER myapp
  ENTRYPOINT ["/usr/local/bin/myapp"]
  ```
- Lint every `Dockerfile` with `hadolint` and add the `hadolint/hadolint`
  pre-commit hook.
- Fix `hadolint` warnings rather than ignore them. If a rule must be
  ignored, add an inline `# hadolint ignore=DLxxxx` with a justification
  comment.

**Never:**

- Never end a `Dockerfile` without an explicit non-root `USER`.
- Never run as `root` in the final image, even "temporarily".
