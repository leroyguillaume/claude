---
name: release-supply-chain-conventions
description: >-
  What a public GitHub release ships beside its artifacts: Sigstore provenance
  attestations, an SBOM, registry provenance, binary signing.
  TRIGGER when: a public GitHub repository's release publishes binaries,
  archives, a checksums file, an image or a package; adding `actions/attest`,
  an SBOM generator, `pypa/gh-action-pypi-publish`, `npm publish` or
  `cargo publish` to a workflow; documenting how to verify a download; user
  asks about provenance, attestations, SBOMs, trusted publishing, code
  signing or notarization.
  SKIP when: the repository is private or publishes nothing; the repo is on
  GitLab (`gitlab-ci-conventions`).
---

# Release supply chain conventions

What a public repository's `release` pipeline (`ci-conventions`) publishes
beside each artifact, so that anyone who downloads it can check that this
repository's CI built it, from which commit, and what it contains. The
workflow mechanics around it are in `github-actions-conventions`.

## Scope: public repositories that publish

All of it applies, with no ask, to a **public** repository whose release
publishes something: a binary, an archive, an image, a package. Nothing here
applies to:

- **a private repository.** Artifact attestations there need GitHub
  Enterprise Cloud, and nobody outside can verify them anyway. No
  attestation, no SBOM.
- **a repository that releases nothing** — docs, configuration, skills, a
  library consumed from source. There is no artifact to vouch for.

## A provenance attestation on every published artifact

`actions/attest`, SHA-pinned, in its default mode: a SLSA build provenance
statement, signed with a short-lived Sigstore certificate bound to the
workflow's OIDC identity, logged in the public-good Sigstore transparency log,
and stored in the repository's attestations. No key to generate, rotate or
leak. `actions/attest-build-provenance` is a thin wrapper over it; new
workflows call `actions/attest` directly.

- **Every artifact the release uploads is a subject**: each binary, each
  archive, **and the checksums file**. A user who checks only the checksums
  file still gets a verified line for every artifact in it. The SBOM gets an
  attestation of its own (below).
- **Attest after the last step that writes the files**, in the job that
  uploads them. A file repacked or renamed after its attestation no longer
  matches it.
- **`id-token: write` and `attestations: write` on that job alone**; the
  workflow stays `contents: read`. The OIDC token is what Sigstore certifies,
  so any other job holding it could sign in the release's name.

```yaml
      - name: attest the release files
        uses: actions/attest@<40-char-sha>  # vX.Y.Z
        with:
          subject-path: dist/*
```

### Images

The `manifest` job, the only one that knows the multi-arch index digest,
attests the image by that digest and pushes the attestation to the registry,
so it travels with the image:

```yaml
      - name: attest the image
        uses: actions/attest@<40-char-sha>  # vX.Y.Z
        with:
          subject-name: ghcr.io/${{ github.repository }}
          subject-digest: ${{ steps.digest.outputs.digest }}
          push-to-registry: true
```

`subject-name` is the fully-qualified image name **without a tag**: the
digest identifies the image. The `digest` step reads it back after the push,
with `docker buildx imagetools inspect <image>:<tag> --format
'{{json .Manifest}}' | jq -r .digest`. GHCR wants it lowercase, so a repository with a
capital in its owner or name lowercases it first. The job already holds
`packages: write` for the push; it adds `id-token: write`,
`attestations: write` and `artifact-metadata: write`, the last for the
storage record the action creates beside the attestation.

## Verifying is documented

An attestation nobody is told how to check protects nobody. The README's
installation (`readme-conventions`) follows each download with its check:

```bash
gh attestation verify <file> --repo <owner>/<repo>
```

```bash
gh attestation verify oci://ghcr.io/<owner>/<repo>:<tag> --repo <owner>/<repo>
```

`--repo`, never `--owner`: `--owner` accepts an attestation from any
repository of that account, including one that never built this artifact.

## Signing a binary

The provenance attestation **is** the default way to sign a binary. Apple
notarisation (a paid Developer ID) and Windows Authenticode (a paid
code-signing certificate) only matter to a file downloaded through a
browser, which Gatekeeper and SmartScreen check; `curl`, a package manager
or `gh release download` never trigger either. Add them only when the user
asks, and then as their own job, holding their own secrets.

## An SBOM with every release

Each release that publishes an artifact attaches one SBOM, in **CycloneDX
JSON**. It is the format built for security tooling: vulnerability scanners
read it directly, and the same format carries VEX statements about which
known CVEs actually affect the artifact. SPDX JSON, the other format
`actions/attest` accepts, only where the user asks for it, typically for a
licence-compliance consumer that requires it.

- **Generate it from what was built**: `anchore/sbom-action`, SHA-pinned, on
  the checkout for files built from it (it reads the lockfiles of every
  ecosystem), on the image for an image. Its default format is SPDX, so set
  it:

  ```yaml
      - name: generate the SBOM
        uses: anchore/sbom-action@<40-char-sha>  # vX.Y.Z
        with:
          format: cyclonedx-json
          output-file: <project>-<version>.cdx.json
  ```

- **Attach it to the release** like any other file, named after the release:
  `<project>-<version>.cdx.json`, written outside `dist/` so it is never a
  subject of its own provenance.
- **Attest it against the artifacts it describes**, which binds the
  inventory to those exact bytes:

  ```yaml
      - name: attest the SBOM
        uses: actions/attest@<40-char-sha>  # vX.Y.Z
        with:
          subject-path: dist/*
          sbom-path: <project>-<version>.cdx.json
  ```

  An image's SBOM is attested with the image's `subject-name` and
  `subject-digest` instead, pushed to the registry the same way.

## Registry provenance and trusted publishing

A package registry that offers trusted publishing gets it: the registry
trusts the workflow's OIDC identity, so no long-lived token sits in the
repository's secrets, and where the registry supports it, the same identity
signs a provenance statement for the upload.

| Registry | How | What the registry shows |
| --- | --- | --- |
| PyPI | `pypa/gh-action-pypi-publish`, no `password` input | PEP 740 attestations for each distribution file, on by default |
| npm | trusted publishing, `npm publish --provenance` | a provenance statement on the package page |
| crates.io | `rust-lang/crates-io-auth-action`, its `token` output as `CARGO_REGISTRY_TOKEN` | no attestation; a short-lived token the action revokes |

- **`id-token: write` on the publishing job alone**, which runs in a GitHub
  environment named after the registry (`pypi`, `npm`, `crates-io`).
- **The trusted publisher is declared on the registry's side** — owner,
  repository, workflow file name, environment — in its web settings. That
  step is the user's; hand them the values, and never fall back to an API
  token stored as a secret.
- Never set `attestations: false` on the PyPI action.

## Never

- Never ask a private repository, or one that releases nothing, for an
  attestation or an SBOM.
- Never grant `id-token: write` beyond the job that attests or publishes,
  and never in a pull-request workflow.
- Never attest a file and then modify it.
- Never verify with `--owner` in the documentation.
- Never add notarisation or Authenticode unasked.
- Never store a registry API token when the registry offers trusted
  publishing.
