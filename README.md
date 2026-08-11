*This project has been created as part of the 42 curriculum by zzin.*

# Inception

## Description

Inception is a system administration project. The goal is to build a small web
infrastructure from scratch inside a virtual machine, using Docker and Docker
Compose, where every service runs in its own container built from a Dockerfile
written by hand — no ready-made images from DockerHub.

The infrastructure is made of three containers:

| Service     | Role                                                              |
| ----------- | ----------------------------------------------------------------- |
| `nginx`     | The only entry point. Serves HTTPS on port 443, TLSv1.2 / TLSv1.3. |
| `wordpress` | WordPress + php-fpm listening on port 9000. No web server inside.  |
| `mariadb`   | The database holding the WordPress tables.                         |

They talk to each other over a private Docker network. Two named volumes hold
the state that must survive a restart: the database files and the WordPress
site files. Both are stored on the host under `/home/zzin/data`.

Full setup and operating instructions are split across
[USER_DOC.md](USER_DOC.md) — running and using the site — and
[DEV_DOC.md](DEV_DOC.md) — building, modifying and troubleshooting it.

## Instructions

### Prerequisites

- A virtual machine (the whole project must run inside one)
- `docker`, `docker compose`, `make` and `git` installed in the VM
- The domain resolving locally — add this line to `/etc/hosts`:

  ```
  127.0.0.1 zzin.42.fr
  ```

### Configuration

Two things are deliberately **not** in the repository, because they contain
credentials:

- `srcs/.env` — non-secret configuration (domain name, database name, database
  user, WordPress site title and usernames)
- `secrets/db_root_password.txt`, `secrets/db_password.txt`,
  `secrets/credentials.txt` — the passwords

They must be recreated locally before the first build. `srcs/.env` looks like
this:

```dotenv
DOMAIN_NAME=zzin.42.fr
LOGIN=zzin

MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser
MYSQL_HOST=mariadb

WP_TITLE=Inception
WP_ADMIN_USER=zzin
WP_ADMIN_EMAIL=zzin@student.42.fr
WP_USER=guest
WP_USER_EMAIL=guest@student.42.fr
```

`secrets/db_root_password.txt` and `secrets/db_password.txt` each contain a
single password. `secrets/credentials.txt` contains the two WordPress
passwords:

```
WP_ADMIN_PASSWORD=...
WP_USER_PASSWORD=...
```

### Running

```sh
make          # create /home/zzin/data, build the images and start the stack
make down     # stop and remove the containers
make clean    # stop, then remove this project's volumes and images
make fclean   # clean, then delete the data on the host
make re       # fclean followed by a full rebuild
```

Once running, the site is reachable at <https://zzin.42.fr>. The certificate is
self-signed, so the browser shows a warning the first time.

## Resources

- [Docker documentation](https://docs.docker.com/) — Dockerfile reference,
  build best practices, networks and volumes
- [Docker Compose file reference](https://docs.docker.com/reference/compose-file/)
- [Docker secrets in Compose](https://docs.docker.com/compose/how-tos/use-secrets/)
- [MariaDB documentation](https://mariadb.com/kb/en/documentation/)
- [WP-CLI handbook](https://make.wordpress.org/cli/handbook/)
- [nginx documentation](https://nginx.org/en/docs/) — `ngx_http_ssl_module`
  and `ngx_http_fastcgi_module`
- [PHP-FPM configuration](https://www.php.net/manual/en/install.fpm.configuration.php)

### Use of AI

AI (Claude) was used as an assistant on the repetitive parts of the project:

- Extracting the requirements from the subject into a checklist
- Scaffolding the repository layout and writing the Makefile
- Drafting this documentation

Every generated file was read, checked against the subject and adjusted before
being committed. The design decisions described below are mine, and I can
explain each line of the configuration.

## Project description

### Use of Docker

Docker is used here as a way to describe a full server setup as code. Each
service is a `Dockerfile` that starts from `debian:bookworm` — the penultimate
stable Debian, as the subject requires — installs exactly one daemon, drops in
its configuration, and runs that daemon in the foreground as PID 1.

Running in the foreground matters: Docker watches process 1: if the daemon
forks into the background, the container exits immediately. That is also why
tricks such as `tail -f` or `sleep infinity` are forbidden — they keep a
container alive whose real service may well be dead, and they hide crashes from
the `restart` policy.

`docker-compose.yml` then wires the three images together: one private bridge
network, two named volumes, the environment file, the secrets, the restart
policy, and the single published port (443 on nginx). The Makefile is a thin
wrapper that creates the host data folders and calls `docker compose`.

### Main design choices

- **`debian:bookworm` everywhere.** The `latest` tag is forbidden and Debian 12
  is the penultimate stable. Using the same base for all three images keeps the
  Dockerfiles readable and lets Docker reuse the same base layer.
- **One daemon per container, in the foreground.** `mariadbd`, `php-fpm` and
  `nginx` each run as PID 1 of their container, so a crash is a container exit,
  which `restart: always` turns into an automatic restart.
- **Secrets on disk, not in the environment.** Passwords live in `secrets/`,
  are mounted read-only at `/run/secrets/...`, and are read by the entrypoint
  scripts. Only non-sensitive values go through `.env`.
- **Only nginx publishes a port.** MariaDB (3306) and php-fpm (9000) are
  reachable on the internal network only; there is no route to them from
  outside the VM.
- **Named volumes bound to `/home/zzin/data`.** The subject requires named
  volumes whose data ends up in that folder, so the volumes are declared with
  `driver: local` and `driver_opts` pointing at the host path.

### Virtual Machines vs Docker

A virtual machine emulates a whole machine: the hypervisor gives it virtual
hardware and it boots its own kernel, with its own init system, drivers and
filesystem. That is heavy — gigabytes of disk, a real boot sequence — but the
isolation is close to total.

A container is just a group of processes on the *host* kernel, fenced off with
namespaces (its own view of the process tree, network stack, mounts, users) and
limited with cgroups. There is no second kernel and no boot: starting a
container is starting a process. An image is a stack of filesystem layers, so
images are small and start-up is instantaneous.

The trade-off is isolation versus cost. Containers share the host kernel, so a
kernel-level escape affects the host, and a container cannot run a different
kernel from the host's. For this project — several cooperating services on one
machine, rebuilt constantly — containers are the right tool, which is why the
subject still asks for a VM around them: the VM provides the isolation, Docker
provides the per-service packaging.

### Secrets vs Environment Variables

Environment variables are the standard way to configure a container, but they
are not private. They are visible in `docker inspect`, in `/proc/<pid>/environ`,
in the output of `env` from any process in the container, and they are
inherited by every child process. If they are written in a `Dockerfile` they
are also baked into the image layers and shipped to whoever pulls it.

Docker secrets take a different route: the value stays in a file, which Compose
mounts read-only into the container at `/run/secrets/<name>`. It never appears
in the image, never in `docker inspect`, and only code that explicitly opens
the file can read it. The cost is a little extra work — the entrypoint has to
read the file instead of using `$VAR` directly.

In this project the split is: `.env` for anything that could be published (the
domain, the database name, the site title), `secrets/` for the three password
files, and both `srcs/.env` and `secrets/*.txt` in `.gitignore`.

### Docker Network vs Host Network

With `network_mode: host` a container skips network namespacing entirely and
uses the host's stack: binding port 443 in the container *is* binding port 443
on the host. It is fast, but every container shares one port space, there is no
isolation between them, and any port a service opens is exposed on the host.

A user-defined bridge network gives each container its own network namespace
and its own IP on a private subnet. Containers on that network reach each other
by service name — Docker runs an embedded DNS server, which is why nginx can
use `fastcgi_pass wordpress:9000;` and WordPress can connect to `mariadb` —
and nothing is reachable from outside unless it is explicitly published with
`ports:`.

That is exactly the requirement here: nginx publishes 443 and nothing else,
while MariaDB and php-fpm stay on the private network. `network: host` and
`links:` are forbidden by the subject for this reason.

### Docker Volumes vs Bind Mounts

A container's writable layer disappears with the container, so anything that
must survive has to be stored outside it.

A **bind mount** maps a specific host path into the container. It is simple and
useful in development — you edit a file on the host and the container sees it
instantly — but it ties the container to the host's directory layout and
inherits the host's ownership and permissions.

A **named volume** is managed by Docker: it has a name, a lifecycle
(`docker volume create/inspect/rm`) independent of any container, and Docker
decides where it lives. It can be inspected, backed up and reattached without
knowing a host path, and it works the same on any machine.

The subject requires named volumes and forbids bind mounts, while also
requiring the data to end up in `/home/zzin/data`. Those are reconciled with
the `local` driver's options: the volume is a real named volume, and
`driver_opts` (`type: none`, `o: bind`, `device: /home/zzin/data/...`) tell the
driver where to back it.
