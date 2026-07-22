---
name: docker-conventions
description: Dockerfile conventions (FHS paths, non-root USER, hadolint with
  no self-authorised ignores, pinned OS packages, .dockerignore).
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
- **Fix every `hadolint` warning at the source.** A green run is the only
  acceptable end state.
- **Pin OS package versions** (`apk add pkg=1.2.3-r4`,
  `apt-get install -y pkg=1.2.3-4`) — this is DL3018/DL3008, and the answer
  is to pin, not to silence. Keeping the pins current is Renovate's job, not
  a reason to skip them. Annotate each one so Renovate can see it:
  ```dockerfile
  # renovate: datasource=repology depName=alpine_3_24/bash versioning=loose
  RUN apk add --no-cache bash=5.3.9-r1
  ```
  Notes that save an hour of debugging:
  - `depName` is `<repology-repo>/<package>`, and the repo carries the
    **distro release** (`alpine_3_24`, `debian_13`). It does **not** follow a
    base-image bump on its own — when the base moves to a new release, the
    annotations must move with it or Renovate silently keeps resolving
    against the old one.
  - Multi-stage builds often sit on **different** distro releases per stage
    (a toolchain image and a runtime image rarely move in lockstep). Check
    each stage (`cat /etc/alpine-release`) and annotate per stage.
  - Take the version from the image itself
    (`apk list <pkg>` / `apt-cache policy <pkg>`), not from Repology's
    `version` field — Repology normalises (`5.3.p9`), and only its
    `origversion` (`5.3.9-r1`) is the string apk will accept.
  - Verify extraction actually works before trusting it:
    `LOG_LEVEL=debug npx --package renovate -- renovate --platform=local
    --dry-run=extract`.

**Never:**

- Never end a `Dockerfile` without an explicit non-root `USER`.
- Never run as `root` in the final image, even "temporarily".
- **Never add a `# hadolint ignore=DLxxxx` on your own initiative** — not
  with a justification comment, not "just this once", not because pinning
  looks brittle. Add one only when the user has expressly asked for that
  specific ignore. If a rule looks genuinely wrong for the situation, say so
  and let the user decide; do not pre-empt the decision by silencing it.
