---
name: docker-conventions
description: Dockerfile conventions (minimal CVE-free base images —
  scratch/distroless first, multi-stage, pinned tags — FHS paths, non-root
  USER, hadolint and Trivy `DS-xxxx` compliance with no self-authorised
  ignores, pinned OS packages, .dockerignore).
  TRIGGER when: editing or creating a `Dockerfile`, `Containerfile`,
  `.dockerignore`, or `docker-compose.yaml`/`compose.yaml`; user asks about
  container build paths, base image choice, image size, container CVEs /
  image scanning, non-root users, or hadolint in this repo.
  SKIP when: pure Python/Rust/Helm/CI work with no Dockerfile touched and the
  user isn't asking about container builds.
---

# Docker conventions

**Always:**

- Create a `.dockerignore` file to exclude unnecessary files from the build
  context (`.git/`, `node_modules/`, `*.log`, `README.md`, etc.).
- **Pick the smallest runtime base image the app can actually run on.** Every
  package in the final image is a CVE waiting to be reported against you, and
  the fastest way to fix a vulnerability is to not ship the package. Walk down
  this ladder and stop at the first rung that works:
  1. `scratch` — statically linked binaries (Rust with `musl`, Go with
     `CGO_ENABLED=0`). Zero packages, zero CVEs, nothing to patch.
  2. **Distroless** (`gcr.io/distroless/static`, `.../base`, `.../cc`) — when
     you need libc, TLS roots, or `/etc/passwd` but no shell or package
     manager. Prefer the `:nonroot` variants.
  3. `alpine` — when you genuinely need a shell or a couple of apk packages.
  4. `*-slim` (`debian:*-slim`, `python:*-slim`) — when glibc or a distro
     runtime is unavoidable.
  Full distro images (`debian`, `ubuntu`, `python:3.13`, `node:22`) are a
  **builder-stage-only** thing; they never appear in the last `FROM`.
- **Always multi-stage.** Compilers, headers, package managers, and dev
  dependencies stay in the builder; the runtime stage gets the artefact and
  nothing else. If the final stage installs a toolchain, the split is wrong.
- **Distroless and `scratch` have no `groupadd`/`useradd`.** Two options, both
  fine, and both land on the same UID 65532 as the rule below:
  - use the upstream `:nonroot` tag and `USER nonroot:nonroot`;
  - or create the user in the builder stage and copy `/etc/passwd` and
    `/etc/group` over.
  Either way the final stage still ends with an explicit non-root `USER`.
- **Scan the built image in CI** (`trivy image` / `grype`) and fail the build
  on `HIGH`/`CRITICAL`. A skinny base is what makes that gate cheap enough to
  keep enabled.
- **Scan the `Dockerfile` itself with `trivy config`, and fix every finding.**
  These are the `DS-xxxx` checks (`DS-0002` running as root, `DS-0026` missing
  `HEALTHCHECK`, `DS-0001` `:latest` tag, `DS-0009` relative `WORKDIR`, …).
  Standing rule, same as everywhere else: **treat them as errors, fix at the
  source, no self-authorised ignores.** Run it locally with
  `trivy config --exit-code 1 Dockerfile`; in `.pre-commit-config.yaml` use a
  `repo: local`, `language: system` hook (never a Docker-backed one — see
  `pre-commit-conventions`).
- **`trivy` does not replace `hadolint`. Run both.** They overlap on the
  obvious stuff (absolute `WORKDIR`, `cd` in `RUN`, `--no-install-recommends`),
  but each catches things the other is blind to:
  - **Only `hadolint`**: OS package version pinning (`DL3008`/`DL3018`) — the
    pinning rule below has *no* Trivy equivalent, which by itself settles the
    question; apt list cleanup (`DL3009`); JSON notation for
    `ENTRYPOINT`/`CMD` (`DL3025`); and **ShellCheck on every `RUN` line**
    (`SC2086` unquoted expansion, etc.), which Trivy does not do at all.
  - **Only `trivy`**: missing `HEALTHCHECK` (`DS-0026`), plus severity levels
    and the same report format as image/IaC scanning.
- **Keep the runtime lean beyond the base image too:** `--no-install-recommends`
  for apt, `--no-cache` for apk, no `curl`/`wget`/`bash` "just for debugging",
  and health checks that use the app itself rather than an extra binary.
- Follow Linux (FHS) path conventions, with `<appname>` the project name:
  - **Build** in `/usr/local/src/<appname>` (the builder stage `WORKDIR`).
  - **Binary** installed to `/usr/local/bin/` (on `PATH`).
  - **Config**, if the app has any, under `/etc/<appname>/`.
  - Any mutable state under `/var/lib/<appname>/`.
- Create a dedicated non-root user and group **named after the app** (use a
  short, recognisable name if the project name is long or not a valid Linux
  username), with **UID 65532 and GID 65532**, `chown` the app-owned paths,
  and end the `Dockerfile` with a `USER` directive.
  Why 65532 and not 1000: UID/GID must be **> 10000** (Trivy `KSV-0020` /
  `KSV-0021`). Without user namespaces, a container UID *is* a host UID, and
  1000 is the first human account on virtually every Linux box — so a
  container escape, a `hostPath` mount, or a shared NFS export lands with
  that user's identity. 65532 is the specific high UID upstream already
  agreed on (`distroless:nonroot`, Chainguard), which keeps the number
  identical whether you inherit the user or create it. Avoid 65534 — that's
  `nobody`/`nogroup`, shared by every unmapped process and squashed-to by NFS.
  Example (app `myapp`):
  ```dockerfile
  # builder stage
  WORKDIR /usr/local/src/myapp
  # ... build, producing /usr/local/src/myapp/target/release/myapp ...

  # runtime stage
  RUN groupadd --system --gid 65532 myapp \
   && useradd  --system --uid 65532 --gid myapp \
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
- **Never ship a full distro image as the runtime stage** because it was
  convenient, because the builder already used it, or because "we might need
  to exec into it". Debugging is what `docker debug`, ephemeral containers,
  and a separate `-debug` tag are for.
- **Never use a floating tag (`:latest`, `:3`, `:bookworm`) in a `FROM`.** Pin
  the specific version, and pin by digest where the registry supports it
  (`image:1.2.3@sha256:…`) — Renovate keeps both current. A floating tag means
  the image you scanned is not the image you shipped.
- **Never silence a scanner finding** (`.trivyignore`, `--severity` downgrade)
  on your own initiative. Same rule as `hadolint ignore`: bump the base image,
  bump the package, or drop the dependency. If none of those work, say so and
  let the user decide.
- **Never add a `# hadolint ignore=DLxxxx` on your own initiative** — not
  with a justification comment, not "just this once", not because pinning
  looks brittle. Add one only when the user has expressly asked for that
  specific ignore. If a rule looks genuinely wrong for the situation, say so
  and let the user decide; do not pre-empt the decision by silencing it.
