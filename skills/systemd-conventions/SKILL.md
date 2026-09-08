---
name: systemd-conventions
description: >-
  systemd unit and cloud-init conventions, centred on the privileges a
  service runs with: never `User=root`, a dedicated system account or
  `DynamicUser=`, the sandboxing block every unit carries, writable paths
  via `StateDirectory=` rather than `chmod`, secrets through
  `LoadCredential=` and never `Environment=`, and `systemd-analyze security`
  as the gate. Plus cloud-init: `runcmd` runs as root, `write_files` needs
  explicit `owner:`/`permissions:`, and user-data is readable forever from
  the metadata endpoint.
  TRIGGER when: creating or editing a `.service`, `.socket`, `.timer` or a
  drop-in `override.conf`; writing a `#cloud-config` / user-data file
  (Terraform `user_data`, a Packer/Ignition script); installing an app on a
  VM so it starts at boot; user asks about systemd, systemctl, service
  hardening, running as root, or cloud-init.
  SKIP when: the workload runs in a container orchestrated by Kubernetes or
  Compose (`docker-conventions` / `helm-conventions`) and no host unit or
  cloud-init file is involved.
---

# systemd and cloud-init conventions

On a VM, the unit file *is* the security boundary — there is no pod security
context, no admission controller, nothing else between the process and the
machine. A service running as root because it was quicker to write is a root
shell one deserialisation bug away. Everything below is about closing that
gap, and it costs about fifteen lines of `ini`.

## The service does not run as root

- **`User=` and `Group=` in every unit, always.** A dedicated system account
  per service, named after the app, with no login shell, no password, no home:

  ```ini
  [Service]
  User=myapp
  Group=myapp
  ```

  Create it declaratively with `systemd-sysusers` (`/usr/lib/sysusers.d/
  myapp.conf`, one line: `u myapp - "myapp service" /var/lib/myapp
  /usr/sbin/nologin`) or from cloud-init's `users:` block — not with a
  `useradd` buried in `runcmd`. The account's own properties — shell, password,
  home, groups, and the file modes around it — are `system-user-conventions`.
- **`DynamicUser=yes` when the service only touches its own state.** systemd
  allocates a transient UID for the lifetime of the unit, and implies
  `ProtectSystem=strict`, `PrivateTmp=`, `RemoveIPC=` and friends. Do not use
  it when the UID must be stable across reboots (NFS, a shared volume, files
  another account reads) — state then lives under `/var/lib/private/` with a
  UID that changes under you.
- **Never `User=root`, and never a wrapper that shells out to `sudo`.** If
  root looks necessary, name the one capability that is actually needed and
  grant only that:

  ```ini
  CapabilityBoundingSet=CAP_NET_BIND_SERVICE
  AmbientCapabilities=CAP_NET_BIND_SERVICE
  ```

  For a port below 1024 the better answer is usually to *not* need the
  capability: bind a high port and put the reverse proxy in front, or let a
  `.socket` unit (owned by root, activated as the service user) hold the
  privileged listener.
- **`ExecStartPre=` runs as the service user too.** If a preparation step
  genuinely needs root, mark that one line `+` (`ExecStartPre=+/usr/bin/…`)
  rather than promoting the whole unit. `PermissionsStartOnly=` is
  deprecated — do not write it.

## The hardening block

Paste this into every long-running unit, then remove only what demonstrably
breaks the app — with a comment saying what broke:

```ini
[Service]
User=myapp
Group=myapp
NoNewPrivileges=true
CapabilityBoundingSet=
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
PrivateDevices=true
ProtectProc=invisible
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectKernelLogs=true
ProtectControlGroups=true
ProtectClock=true
ProtectHostname=true
RestrictNamespaces=true
RestrictRealtime=true
RestrictSUIDSGID=true
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
LockPersonality=true
MemoryDenyWriteExecute=true
SystemCallArchitectures=native
SystemCallFilter=@system-service
UMask=0077
StateDirectory=myapp
```

What each of the load-bearing ones actually buys, since a directive nobody
understands is a directive somebody deletes:

- **`NoNewPrivileges=true`** — the process and every child can never gain
  privileges again, so a setuid binary reachable from the service (`sudo`,
  `mount`, `pkexec`) becomes inert. This is the single highest-value line;
  it is also what makes `SystemCallFilter=` enforceable.
- **`ProtectSystem=strict`** — the entire filesystem is read-only except
  `/dev`, `/proc`, `/sys`. Combined with `ProtectHome=true` (`/home`,
  `/root`, `/run/user` empty), a compromised service cannot persist anything
  on disk.
- **`CapabilityBoundingSet=`** (empty) — drops every capability, including
  the ones a root-owned parent might have handed down. List capabilities
  explicitly when one is genuinely needed; never leave it unset.
- **`MemoryDenyWriteExecute=true`** — blocks W+X mappings. It **breaks every
  JIT runtime**: Node, the JVM, .NET, LuaJIT, anything with a tracing JIT.
  Drop it for those, keep it for Rust/Go/C binaries.
- **`SystemCallFilter=@system-service`** — a seccomp allowlist covering what
  a normal daemon does. Add narrow groups when needed
  (`SystemCallFilter=~@privileged @resources` style subtraction is fine),
  never replace it with nothing.

## Writable paths are declared, not chmod-ed

`ProtectSystem=strict` means the app cannot write anywhere it has not been
given. Grant that with the `*Directory=` directives, never with a `mkdir -p`
plus `chown` in provisioning:

| Need | Directive | Path | Owner/mode |
| --- | --- | --- | --- |
| Persistent state | `StateDirectory=myapp` | `/var/lib/myapp` | service user, `0700` |
| Runtime sockets/PIDs | `RuntimeDirectory=myapp` | `/run/myapp` | service user, `0700`, wiped on stop |
| Caches | `CacheDirectory=myapp` | `/var/cache/myapp` | service user, `0700` |
| Own log files | `LogsDirectory=myapp` | `/var/log/myapp` | service user, `0700` |
| Config | `ConfigurationDirectory=myapp` | `/etc/myapp` | root-owned, readable |

systemd creates them with the right owner and mode before `ExecStart=`, and
recreates them if they are missing — provisioning that pre-creates them by
hand is one `chown` away from being wrong and never noticed. `ReadWritePaths=`
is the last resort, for a path the app does not own (a data mount, a socket
directory shared with another service); list the narrowest path that works.

Logging goes to **stdout/stderr and the journal** — no log file, no logrotate
config, no `LogsDirectory=` at all in the normal case. See
`logging-conventions`.

## Secrets never sit in the unit file

- **Never `Environment=API_TOKEN=…`.** Unit files are world-readable, and
  `systemctl show myapp.service` prints the environment to any unprivileged
  user on the box. Same for a secret on the `ExecStart=` command line: it is
  in `/proc/<pid>/cmdline`, visible in `ps`.
- **Prefer `LoadCredential=`**: the file is mounted read-only into the
  service's private credential directory, owned by the service user, invisible
  to every other process and never in the journal:

  ```ini
  LoadCredential=api-token:/etc/myapp/api-token
  ```

  The app reads `$CREDENTIALS_DIRECTORY/api-token`. `SetCredential=` inlines a
  value in the unit — that is the same leak as `Environment=`, so only for
  non-secret data.
- `EnvironmentFile=/etc/myapp/env` is the acceptable fallback for apps that
  only read the environment: `root:myapp`, mode `0640`, never `0644`.

## cloud-init

The provisioning file is where privileges are handed out for the life of the
machine, and it is *very* easy to hand out too many.

- **`runcmd` and `bootcmd` run as root**, once, at first boot, with no
  sandbox. Use them to *install and enable* — `systemctl enable --now
  myapp.service` — never to run the application itself. An app started from
  `runcmd` is a root process with no unit, no restart, no hardening and no
  journal identity.
- **Every `write_files` entry carries explicit `owner:` and `permissions:`.**
  The defaults are `root:root` and `0644`; a credential written with the
  defaults is readable by every account on the machine. Quote the mode so
  YAML does not mangle the leading zero:

  ```yaml
  write_files:
    - path: /etc/myapp/api-token
      owner: root:myapp
      permissions: '0640'
      content: ""
    - path: /etc/systemd/system/myapp.service
      owner: root:root
      permissions: '0644'
      content: |
        [Unit]
        Description=myapp
  ```

- **The service account gets no sudo, ever.** Create it locked down, and keep
  sudo for the human/admin account the user explicitly asked for:

  ```yaml
  users:
    - name: myapp
      system: true
      shell: /usr/sbin/nologin
      lock_passwd: true
  ```

- **Lock the box's own doors**: `disable_root: true`, `ssh_pwauth: false`,
  keys via `ssh_authorized_keys` only. No password hashes in user-data.
- **Never put a secret in user-data.** It stays readable for the instance's
  entire life from the metadata endpoint (`169.254.169.254`) by *any* process
  on the machine, including the compromised one, and most providers keep it in
  the instance description too. Provision the value from the cloud's secret
  manager at boot, or place the file out of band and reference it with
  `LoadCredential=`.
- **`write_files` runs before `runcmd`** — rely on that ordering rather than
  re-writing files from `runcmd`. After dropping a unit file, `runcmd` needs
  `systemctl daemon-reload` before `enable --now`.
- Block style YAML only (`yaml-conventions`), and validate the file:
  `cloud-init schema --config-file cloud-config.yaml`.

## Verify, don't assume

- **`systemd-analyze security myapp.service` is the lint for a unit.** Run it
  after every unit change. A bare unit with no hardening scores around 9.6
  ("UNSAFE"); the block above typically lands between 1 and 3 ("OK"). Treat
  anything above 5.0 as unfinished work, and read the per-directive table it
  prints rather than guessing which line is missing. For a unit file in the
  repo that is not installed, `systemd-analyze security --offline=true
  ./myapp.service` (systemd ≥ 250).
- `systemd-analyze verify ./myapp.service` catches typos and bad references —
  an unknown directive is silently ignored at runtime, so a misspelled
  `ProtectSytem=` fails open, quietly, forever.
- `systemctl show myapp.service -p User -p CapabilityBoundingSet -p
  NoNewPrivileges` after deploying: it prints what is *effective*, which is
  the only thing that counts. And `systemctl status` should show the service
  running under the expected UID.
- Vendor units are never edited in place. Override with a drop-in:
  `/etc/systemd/system/myapp.service.d/override.conf`, then
  `systemctl daemon-reload`.

## Also in the unit, while you are there

- `Restart=on-failure` with `RestartSec=` — and the process handles `SIGTERM`
  so the restart is clean (`signal-handling-conventions`).
- `Type=notify` when the app can signal readiness, `Type=exec` otherwise.
  `Type=simple` claims readiness before the process has done anything, so
  `After=` ordering on it means nothing.
- `TimeoutStopSec=` longer than the app's drain window, otherwise systemd
  `SIGKILL`s mid-drain — exactly the failure the drain logic exists to avoid.
