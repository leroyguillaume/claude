---
name: system-user-conventions
description: >-
  Unix account conventions — a service account is not a person. One
  dedicated system account per service, `nologin` shell, locked password, no
  home under `/home`, no sudo and no root-equivalent group (`docker`,
  `wheel`), never `nobody`, never shared. Created declaratively (`systemd-
  sysusers`, cloud-init `users:`, Ansible, `useradd --system`), never by an
  interactive `adduser`. The service never owns its own binary, config is
  `root:<app>` `0640`, state is `0700`, and `chown -R` is not a fix.
  TRIGGER when: creating or reviewing a Unix account or group —
  `useradd`/`usermod`/`groupadd`, a `sysusers.d` file, a cloud-init `users:`
  block, an Ansible `user` task, a `Dockerfile` `USER`; granting sudo or
  adding someone to a group; setting ownership or modes on files a service
  reads or writes; wiring SSH access, authorized keys or a deploy/CI
  account; user asks who a process runs as, why a login fails, or how to
  lock an account down.
  SKIP when: no account, group, ownership or login path is involved.
---

# System user conventions

A service account exists so that a compromised process is stuck being that
process: it cannot log in, cannot be logged into, cannot become anything else,
and owns nothing it does not strictly need. Every property below removes one
way out of that box — which is why "it was easier with a shell" is never a
reason.

The unit-file side of this (`User=`, `DynamicUser=`, the sandboxing block)
lives in `systemd-conventions`; the container side (UID/GID 65532, distroless
`nonroot`) in `docker-conventions`. This skill is the account itself, wherever
it is created.

## The account

- **One account per service, named after the app.** Never a shared catch-all
  (`www-data` running three apps means a bug in one reads the secrets of the
  other two), and never a human's account.
- **Never `nobody` / `nogroup` (65534).** It is shared by every unmapped
  process on the box and is what NFS squashes root to, so "owned by `nobody`"
  effectively means "owned by everybody". Same reasoning as avoiding it in
  containers.
- **`--system`**: a UID from the system range (100–999 on Debian/RHEL), no
  password aging, no expiry, not counted as a login account. In a container
  image the number is different on purpose — UID/GID **65532**, see
  `docker-conventions` — because a container UID is a host UID.
- **Shell `/usr/sbin/nologin`** (`/sbin/nologin` on RHEL and Alpine). It
  refuses the session and exits non-zero, which kills interactive SSH, `su -`,
  *and* `ssh host command` — everything goes through the login shell. Prefer it
  to `/bin/false`, which does the same thing silently and leaves the user
  wondering. Never `/bin/bash` "for debugging": to get a shell as the service
  account, use `sudo -u myapp` on a specific command, `runuser -u myapp -- …`,
  or `systemd-run --uid=myapp --pty …`. None of those need the account to have
  a shell of its own.
- **Password locked**, never a hash, and never an empty field — an empty
  second field in `/etc/shadow` is a passwordless account, which some PAM
  stacks happily accept. `passwd --lock` / `lock_passwd: true` / `password:
  '!'` all write the `!` that means "locked".
  Caveat worth knowing: **locking the password does not block SSH key auth.**
  `nologin` plus an empty `~/.ssh/authorized_keys` is what closes that door.
- **No home directory under `/home`.** `/home` is for humans, is frequently a
  separate or NFS-mounted filesystem, and `useradd -m` copies `/etc/skel`
  dotfiles nobody will ever read. Either give the account no home at all, or
  point it at the state directory the service already has
  (`/var/lib/myapp`) — created by systemd's `StateDirectory=`, not by
  `useradd -m`.
- **No sudo, no `wheel`, no `adm`.** And specifically **no `docker` group**:
  a member can run `docker run -v /:/host`, which is root with extra steps.
  `lxd` and `libvirt` are the same trap. Adding a service account to any of
  them undoes every other line on this page.
- **Supplementary groups only for a resource the service must actually
  reach**, one group per shared resource (`myapp` in `certs` to read a TLS
  key). Not "because it was the quickest way to fix a permission error".

## Create it declaratively

Provisioning that runs `useradd` imperatively has to answer "what if it
already exists?" — `useradd` exits 9 when it does, so the script fails on the
second run. Every form below is idempotent by construction:

- **`systemd-sysusers`** is the default on a systemd host or in an image —
  `/usr/lib/sysusers.d/myapp.conf`, applied at package install and at boot:

  ```
  #Type Name  ID  GECOS            Home dir      Shell
  u     myapp -   "myapp service"  /var/lib/myapp /usr/sbin/nologin
  ```

- **cloud-init**, when the account comes up with the machine:

  ```yaml
  users:
    - name: myapp
      system: true
      shell: /usr/sbin/nologin
      lock_passwd: true
      create_home: false
  ```

- **Ansible**: `ansible.builtin.user` with `system: true`, `shell:
  /usr/sbin/nologin`, `create_home: false`, `password: '!'`.
- **`Dockerfile`**: `useradd --system --uid 65532 --gid myapp --shell
  /usr/sbin/nologin --home /etc/myapp myapp` (full form and rationale in
  `docker-conventions`).
- **A shell script, only when nothing above fits** — and then guarded:

  ```sh
  id -u myapp >/dev/null 2>&1 || useradd --system \
      --shell /usr/sbin/nologin --home-dir /var/lib/myapp --no-create-home myapp
  ```

Never an interactive `adduser` in a runbook: it prompts, so it cannot be
automated, and it silently defaults to a real shell and a `/home` directory.

## What the account owns

The account's privileges are not only in `/etc/passwd` — they are in the file
modes around it.

| Thing | Owner | Mode | Why |
| --- | --- | --- | --- |
| Binary, `/usr/local/bin/myapp` | `root:root` | `0755` | A service that can write its own binary rewrites it after a compromise and survives every restart |
| Unit file, timers, `/etc/systemd/**` | `root:root` | `0644` | Writing them is a direct path back to root |
| Config, `/etc/myapp/` | `root:myapp` | `0640` | Readable by the service, writable by nobody but root |
| Secret file | `root:myapp` | `0640`, or `0600` with `LoadCredential=` | See `systemd-conventions` |
| State, `/var/lib/myapp/` | `myapp:myapp` | `0700` | The one place it writes |

- **`chown -R myapp /opt/myapp` is not a fix.** When a permission error shows
  up, find the single path that must be writable and grant that one — usually
  it turns out to be a `StateDirectory=` that was missing.
- **`chmod 777` is never the answer**, in any script, ever. If two accounts
  must share a directory, that is a group plus `2770` (setgid so new files
  inherit the group), not world-writable.
- **`UMask=0077`** in the unit, so whatever the app creates at runtime is not
  readable by the rest of the box by default.

## Humans are the mirror image

- **One account per person, never a shared `admin` / `deploy` / `ops`
  login.** A shared account has no audit trail: `sudo` logs "admin ran
  `rm -rf`", and the machine has no idea which of the six people that was.
- Real shell, **key-based SSH only** (`PasswordAuthentication no`,
  `PermitRootLogin no`), **sudo through a group** (`wheel` / `sudo`), not a
  per-user `sudoers` line. `NOPASSWD` only where the workflow genuinely cannot
  prompt, and scoped to the commands that need it.
- **A CI or deploy account that must accept SSH is the one exception to
  `nologin`** — it needs a shell to run the command. Constrain it instead:
  a forced command and lockdown options in `authorized_keys`
  (`restrict,command="/usr/local/bin/deploy"`), no sudo, no interactive
  session, and its own key per pipeline so a single key can be revoked.
- Removing someone is removing the account, not just their key — and their
  group memberships go with it.

## Audit what is actually on the box

Cheap checks worth running when you inherit a machine or finish provisioning
one:

```sh
# accounts that can actually log in
awk -F: '$7 !~ /(nologin|false)$/ {print $1, $3, $7}' /etc/passwd

# unlocked passwords (anything not marked L)
passwd -Sa 2>/dev/null | awk '$2 != "L" {print $1, $2}'

# empty password field — passwordless login on a permissive PAM stack
awk -F: '$2 == "" {print $1}' /etc/shadow

# who holds root-equivalent group membership
getent group sudo wheel adm docker lxd libvirt
```

And the one that matters most after a deploy: `systemctl show myapp.service
-p User -p Group` — the account the service *actually* runs as, rather than
the one the config says it should.
