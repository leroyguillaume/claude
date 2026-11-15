---
name: security-policy-conventions
description: >-
  SECURITY.md: how to report a vulnerability in a public repository, and what
  happens next.
  TRIGGER when: creating or editing `SECURITY.md`; a repository is or becomes
  public; scaffolding a public project; user asks how people should report a
  vulnerability, or about a security policy.
  SKIP when: the repository is private; fixing or scanning for a
  vulnerability (`ci-conventions`).
---

# Security policy conventions

A `SECURITY.md` answers one question: **"I found a vulnerability in this
project — how do I tell the maintainers without telling everyone else?"**
GitHub shows it under the repository's Security tab and links it from the
new-issue page, which is where a reporter about to open a public issue looks.

## Every public repository has one, at the root

- **Public repository → `SECURITY.md` at the repository root.** GitHub also
  reads `.github/` and `docs/`, but the root is where a reader browsing the
  tree finds it, and one location is one home.
- **Private repository → none.** Its reporters are its members, who have
  better channels than a file.
- In English, present tense, like every document
  (`documentation-conventions`).

## Structure

```markdown
# Security policy

## Reporting a vulnerability

## Supported versions

## Scope

## What happens next
```

### Reporting a vulnerability

- **Through GitHub's private vulnerability reporting**, linked directly:
  `https://github.com/<owner>/<repo>/security/advisories/new`. The report
  opens a draft advisory only the maintainers and the reporter see, where the
  fix can be discussed and prepared.
- **Never a public issue, pull request or discussion**, and say so in one
  line: a vulnerability described in public is disclosed before it is fixed.
- The link only works with private vulnerability reporting switched on;
  turning it on is `github-repo-settings`' job, in the same change that adds
  the file.
- **No email address unless the user gives one for this purpose.** Private
  reporting already reaches the maintainers, and an address published here is
  one more inbox someone has to watch for reports.
- What a useful report holds, as a short list: the affected version, the
  steps to reproduce, the impact as the reporter sees it.

### Supported versions

**State the policy, not a table of version numbers.** A `1.4.x ✅` table goes
stale at the next release, and nobody remembers to update it
(`documentation-conventions`). Write the rule instead:

- a project that cuts releases: "fixes ship in a new release; only the
  latest release is supported";
- a project that does not: "the default branch is the only supported
  version".

Support for older lines is the user's call; write it only when they state
it.

### Scope

What counts as a vulnerability **in this project**, in a few bullets drawn
from what it is: its own code and the artifacts it publishes, with the
attack surface that makes sense for it (an HTTP API, a CLI parsing untrusted
input, a container image, a chart's defaults). Then what is out of scope:

- a vulnerability in a dependency, already public upstream: report it there;
  the dependency bot (`dependency-update-conventions`) brings the fix in;
- a finding that needs an already-compromised host or account;
- scanner output with no path to exploitation.

### What happens next

The steps a report goes through, as an ordered list: acknowledged, assessed,
fixed in the advisory's private fork, released, then the advisory published —
with a CVE requested through GitHub when the impact warrants one — and the
reporter credited unless they prefer otherwise.

**No response time unless the user gives one.** An invented SLA is a promise
the maintainer did not make; without one, say that reports are handled on a
best-effort basis.

## Never

- Never create a `SECURITY.md` in a private repository.
- Never invite a report through a public issue, pull request or discussion.
- Never invent a contact address or a response time.
- Never list supported versions as a table of numbers.
