# Inception — Developer Documentation

How the infrastructure is built, how to set it up from nothing, and how to
work on it. For day-to-day use, see [USER_DOC.md](USER_DOC.md).

## Prerequisites

- A virtual machine — the subject requires the whole project to run inside one
- `docker` (Engine) and the `docker compose` v2 plugin
- `make`, `git`
- `sudo` rights, needed by `make fclean` to delete root-owned database files

Verify:

```sh
docker --version && docker compose version && make --version
```

## Setting up from scratch

Two sets of files are deliberately absent from the repository because they
hold configuration and credentials. Both must be recreated after cloning.

### 1. `srcs/.env`

```dotenv
DOMAIN_NAME=zzin.42.fr
LOGIN=zzin

# The one value that differs between machines — see "Portability" below.
DATA_PATH=/home/zzin/data

MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser
MYSQL_HOST=mariadb

WP_VERSION=6.7.1
WP_TITLE=Inception
WP_ADMIN_USER=zzin
WP_ADMIN_EMAIL=zzin@student.42.fr
WP_USER=guest
WP_USER_EMAIL=guest@student.42.fr
```

`WP_ADMIN_USER` must not contain `admin`, `Admin` or `administrator` — the
subject rejects those outright.

### 2. `secrets/`

Three files, each holding a password and nothing else:

```sh
openssl rand -base64 24 | tr -d '/+=' | cut -c1-20 > secrets/db_root_password.txt
openssl rand -base64 24 | tr -d '/+=' | cut -c1-20 > secrets/db_password.txt
{ echo "WP_ADMIN_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-20)"
  echo "WP_USER_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-20)"
} > secrets/credentials.txt
chmod 600 secrets/*.txt
```

`db_root_password.txt` and `db_password.txt` contain a bare password.
`credentials.txt` contains two `KEY=value` lines, because the WordPress
entrypoint sources it as a shell fragment.

### 3. Host resolution

```sh
echo "127.0.0.1 zzin.42.fr" | sudo tee -a /etc/hosts
```

### 4. Build

```sh
make
```

Confirm nothing sensitive is tracked:

```sh
git status --porcelain      # must not list srcs/.env or secrets/*
```

## Layout

```
.
├── Makefile                 # entry point; owns DATA_PATH
├── README.md                # project write-up (graded)
├── USER_DOC.md
├── DEV_DOC.md
├── secrets/                 # gitignored
│   ├── credentials.txt
│   ├── db_password.txt
│   └── db_root_password.txt
├── notes/                   # personal study material, not part of the build
└── srcs/
    ├── .env                 # gitignored
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/{Dockerfile,conf/50-server.cnf,tools/entrypoint.sh}
        ├── nginx/{Dockerfile,conf/default.conf.template,tools/entrypoint.sh}
        └── wordpress/{Dockerfile,conf/www.conf,tools/entrypoint.sh}
```

Every service follows the same shape: a `Dockerfile`, its config under
`conf/`, its startup script under `tools/`.

## How a build works

`make up` does two things:

1. `mkdir -p $(DATA_PATH)/{mariadb,wordpress}` — the bind-backed named volumes
   refuse to mount if their host directory does not already exist.
2. `docker compose -f srcs/docker-compose.yml up -d --build`

Startup order is `mariadb` → `wordpress` → `nginx` via `depends_on`. Note that
`depends_on` only orders *container start*, not *service readiness*: the
WordPress entrypoint polls `mariadb-admin ping` in a loop until the database
actually answers. Removing that loop reintroduces a race that fails roughly
half the time on a cold build.

Each container's entrypoint is idempotent — it detects existing state and
skips initialisation — because `restart: always` means it can run many times
against the same volume.

| Service   | First boot does                                    | Guarded by                    |
| --------- | -------------------------------------------------- | ----------------------------- |
| mariadb   | `mariadb-install-db`, then create DB/user via bootstrap | `-d /var/lib/mysql/mysql` |
| wordpress | `wp core download`, `wp config create`, `wp core install` | `-f wp-config.php`, `wp core is-installed` |
| nginx     | generate self-signed cert, render config template   | `-f inception.crt`            |

## Container and volume management

```sh
make ps                       # status of the three services
make logs                     # follow all logs
docker logs -f wordpress      # one service

docker exec -it mariadb bash  # shell inside a container
docker exec -it mariadb mariadb -u root -p          # DB console
docker exec -it wordpress wp user list --allow-root # list WP users

docker volume ls
docker volume inspect db_data    # confirm Mountpoint is under DATA_PATH
docker network inspect inception # confirm all three are attached
```

Rebuilding one service without touching the others:

```sh
docker compose -f srcs/docker-compose.yml up -d --build nginx
```

## Where the data lives

Two named volumes, both backed by a host directory:

| Volume     | Mounted at         | Host path                   | Holds                |
| ---------- | ------------------ | --------------------------- | -------------------- |
| `db_data`  | `/var/lib/mysql`   | `$DATA_PATH/mariadb`        | the database files   |
| `wp_files` | `/var/www/html`    | `$DATA_PATH/wordpress`      | WordPress core + uploads |

`wp_files` is mounted into **both** `wordpress` and `nginx` — php-fpm executes
the PHP, nginx serves the static assets, and both need the files on disk.

The subject requires named volumes *and* requires the data to be in
`/home/<login>/data`. Those are reconciled with the local driver's options:

```yaml
db_data:
  driver: local
  driver_opts: { type: none, o: bind, device: ${DATA_PATH}/mariadb }
```

This is a genuine named volume — it has a name, appears in `docker volume ls`,
and has a lifecycle independent of any container — that happens to be backed
by a known host path. A bind mount, by contrast, cannot be declared under the
top-level `volumes:` key at all.

Persistence rules:

- `make down` — containers removed, **volumes kept**. Data survives.
- `make clean` — `down -v --rmi all`. **Volumes destroyed.**
- `make fclean` — also `rm -rf` the host directories. Needs `sudo`, because
  the files inside are owned by the container's `mysql` user.

## Portability between machines

`DATA_PATH` is the only value that legitimately differs across machines,
because it follows the **unix user**, not the 42 login. The Makefile derives
it at runtime:

```make
LOGIN     ?= $(shell id -un)
DATA_PATH ?= /home/$(LOGIN)/data
export DATA_PATH
```

Since an exported shell variable takes precedence over `srcs/.env`, the
Makefile always wins, and the same clone works on a personal machine and on
the school session with no edit. Override explicitly when needed:

```sh
make LOGIN=zzin
```

`DOMAIN_NAME` stays `zzin.42.fr` everywhere — it is the 42 login, not the unix
user, so it does not change.

## Constraints the code must keep satisfying

- Base image is `debian:bookworm` — penultimate stable; `latest` is forbidden
- Image name == service name
- One service per container, no nginx inside the wordpress image
- No `network_mode: host`, no `links:`, no `--link`
- No `tail -f`, `sleep infinity`, `while true` as a command
- No password in any Dockerfile or in any committed file
- Only nginx publishes a port, and only 443, TLSv1.2/1.3 only
- Every daemon runs in the foreground as PID 1, reached via `exec "$@"`

Quick audit:

```sh
grep -rn "latest" srcs/                     # must return nothing
grep -rniE "password|passwd" srcs/requirements/*/Dockerfile   # nothing
grep -rnE "tail -f|sleep infinity|while true" srcs/           # nothing
```
