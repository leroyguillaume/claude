---
name: release-script-conventions
description: >-
  Release conventions — every publishable project ships a
  `scripts/release.sh` that bumps the version stored in the repo, regenerates
  what derives from it, commits, tags, and asks before pushing; the git tag is
  what CI publishes from, and CI refuses to publish when the tag and the
  committed version disagree.
  TRIGGER when: creating or editing a release/bump script; wiring release
  automation for a repo; adding a `version`/`appVersion` field or changing how
  one is set; a release workflow triggered by a `v*` / `chart-*` tag; user asks
  how to cut, tag, publish or version a release, or asks to bump a version.
  SKIP when: routine work that merely reads a version, and the user isn't
  asking about releasing.
---

# Release script conventions

## Every publishable project ships `scripts/release.sh`

Cutting a release by hand is three separate steps — edit the version,
regenerate whatever derives from it, tag with a name that matches — on the one
operation that is awkward to undo once it has reached a registry. Three chances
to get it wrong, and the failure mode is a published artefact whose metadata
lies about what it is.

One script does all of it, in order, or none of it:

1. bump the version stored in the repository
2. regenerate every file derived from that version
3. commit
4. tag
5. **ask** before pushing

The script is the only supported way to cut a release. Say so in `README.md`
and `CONTRIBUTING.md`, and make CI enforce it (see the drift guard below).

## The version lives in two places, and one tool writes both

- **The tag is what CI publishes from.** `vX.Y.Z` → the image tag, the crate
  version, the GitHub release. Derive it at build time; never read it out of a
  file.
- **The repository still carries the same number**, because a manifest whose
  version is permanently `0.0.0` lies to every tool that reads it — package
  managers, SBOM generators, dependency scanners, the user running
  `--version`.

These two are only safe because a single command writes both in one commit.
That is the whole justification for the script existing; without it, two
sources of truth is exactly the anti-pattern it looks like.

## Where the version lives, per ecosystem

Use the ecosystem's own tool. It updates the lockfile as well, which hand-editing
does not.

| Ecosystem | Files | How to write it |
| --- | --- | --- |
| npm | `package.json`, `package-lock.json` | `npm version <v> --no-git-tag-version` |
| Rust | `Cargo.toml`, `Cargo.lock` | `cargo set-version <v>` (`cargo-edit`) |
| Python | `pyproject.toml`, `uv.lock` | `uv version <v>` |
| Helm | `Chart.yaml` (`version`, `appVersion`) | `sed` on the **anchored** top-level keys (`^version:`), then re-run `helm-docs` |

**Never hand-edit a lockfile** to match a bumped manifest, and never write a
version with an unanchored `sed` — `version:` appears inside dependency blocks
too.

## Regenerate what derives from the version

Anything generated from the version must be regenerated in the same commit, or
the release commit fails its own pre-commit gate:

- `helm-docs` chart READMEs — the badges embed `version` **and** `appVersion`
- lockfiles — handled by the ecosystem tool above
- any `--help` dump or generated doc that prints the version

Run the generator with the *same* invocation the pre-commit hook uses, so the
output is byte-identical and the hook stays green.

## Never push on its own — ask

Pushing the tag is what publishes. That is outward-facing and effectively
irreversible once a registry has served it, so it is never automatic:

```bash
printf 'push %s and %s to origin? this publishes the release. [y/N] ' "$branch" "$tag"
read -r reply
```

- **Default to No.** A bare Enter declines.
- **No terminal, no push.** Guard with `[ -t 0 ]` and decline when stdin is not
  a TTY — a pipe or a CI job must not publish, and `read` must not hang.
- **Declining is not a failure.** Print the exact push command so the user can
  run it later; the commit and tag stay on their machine.
- **No `--push` / `--yes` escape hatch.** A flag that skips the question is the
  question not being asked. Automation that genuinely should publish pushes the
  tag itself rather than driving this script.

## Refuse rather than guess

Check all of these before touching anything, and `exit 1` with a message naming
the fix:

- the version argument is **semver**, and given explicitly — never infer a bump
  from commit messages or auto-increment a component
- the working tree is **clean**
- the branch is the **default branch**
- the branch is **not behind origin** (`git fetch` first, then
  `git rev-list --count HEAD..origin/<branch>`)
- the **tag does not already exist**
- for a chart, the `appVersion` being pinned **refers to a real released tag**

## Separate lifecycles get separate tag namespaces

When a repo publishes more than one artefact — an application and its Helm
chart is the common case — each versions independently:

- `vX.Y.Z` → the application
- `chart-X.Y.Z` → the chart, selected with a `--chart` flag

For a chart, default `appVersion` to the most recent `v*` tag so a chart release
targets the newest application release, and expose `--app-version` to pin a
different one. `version` comes from the chart's own tag; the two never share a
number.

## CI must guard the drift

Two sources of truth are only safe if disagreement is loud. Every
tag-triggered publish workflow re-derives the version from the tag and refuses
to run when the committed file disagrees:

```yaml
      - name: derive the version from the tag
        id: version
        run: |
          version="${GITHUB_REF_NAME#v}"
          committed="$(jq -r .version package.json)"
          if [ "$committed" != "$version" ]; then
            echo "package.json says ${committed} but the tag says ${version}." >&2
            echo "Cut releases with scripts/release.sh so the two stay in step." >&2
            exit 1
          fi
          echo "version=${version}" >> "$GITHUB_OUTPUT"
```

This is what makes hand-tagging fail fast instead of publishing a mislabelled
artefact.

## `--dry-run`

Report the current and target values, the commit subject and the tag, then
stop. Change nothing, and never prompt — there is nothing to push.

## Shape and quality

- `#!/usr/bin/env bash`, `set -euo pipefail`, and **`shellcheck` clean** — wire
  the script into the `shellcheck` pre-commit hook like any other
  (see `pre-commit-conventions`).
- A `usage()` heredoc behind `-h` / `--help`, with worked examples.
- `cd "$(git rev-parse --show-toplevel)"` so it works from any subdirectory.
- Annotated tags (`git tag --annotate`), so the tag carries an author and date.
- Errors to stderr through a `die()` helper; never `exit 0` on a failed check.

**Never:**

- Never bump a version outside this script — not in a normal commit, not "just
  this once". The global rule that **Claude never bumps a version unasked**
  still applies: the script exists for the user to run, and writing it is not
  permission to run it.
- Never push, tag, or publish without the user having asked for a release.
- Never hand-edit a lockfile to match a bumped manifest.
- Never continue past a dirty tree, a stale branch, or an existing tag.
- Never cut a release by editing a version field and tagging separately — that
  is precisely the drift the CI guard rejects.
