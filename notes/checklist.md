# Inception — TODO (mandatory only)

Checklist built from the subject PDF (version 5.3). Replace `<login>` with your 42 login everywhere.

---

## 0. Setup

- [ ] Create a **Virtual Machine** (the whole project must run inside it)
- [ ] Install `docker`, `docker compose`, `make`, `git` in the VM
- [ ] Init the git repo; add a `.gitignore` that ignores `srcs/.env` and `secrets/`
- [ ] Add `127.0.0.1 <login>.42.fr` to `/etc/hosts` in the VM
- [ ] Create the host data folders: `/home/<login>/data/mariadb` and `/home/<login>/data/wordpress`

## 1. Directory structure

```
.
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
├── secrets/
│   ├── credentials.txt
│   ├── db_password.txt
│   └── db_root_password.txt
└── srcs/
    ├── .env
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/{Dockerfile,conf/,tools/}
        ├── nginx/{Dockerfile,conf/,tools/}
        └── wordpress/{Dockerfile,conf/,tools/}
```

- [ ] `Makefile` at the **root**, `srcs/` holds all config
- [ ] One `Dockerfile` per service, written by me (no pulling ready-made images)

## 2. Rules I must not break

- [ ] Base image = **penultimate stable** Debian or Alpine (e.g. `debian:bookworm`, not `latest`)
- [ ] The `latest` tag is **forbidden**
- [ ] Image name == service name
- [ ] One service per container
- [ ] **No** `network: host`, **no** `--link`, **no** `links:` — a `networks:` section must exist in `docker-compose.yml`
- [ ] **No** infinite-loop hacks as entrypoint: `tail -f`, `sleep infinity`, `while true`, bare `bash`
- [ ] **No passwords in Dockerfiles** — env vars + `.env` mandatory, Docker secrets strongly recommended
- [ ] No credentials committed to git
- [ ] Containers restart in case of a crash (`restart: always`)
- [ ] NGINX is the **only** entrypoint, port **443 only**, **TLSv1.2 / TLSv1.3 only**

## 3. MariaDB container

- [ ] Dockerfile from Debian/Alpine, install `mariadb-server`, no nginx
- [ ] Config file → bind to `0.0.0.0`
- [ ] Init script: create the WordPress database + user + root password from env/secrets
- [ ] Run `mysqld` / `mariadbd` in the **foreground** as PID 1
- [ ] Named volume mounted on `/var/lib/mysql`
- [ ] Only reachable on the internal docker network (3306 not published)

## 4. WordPress + php-fpm container

- [ ] Dockerfile from Debian/Alpine, install `php-fpm` + php extensions (`php-mysqli`, etc.), **no nginx**
- [ ] Install `wp-cli` and download WordPress
- [ ] Entrypoint script: wait for MariaDB, `wp core download` / `wp config create` / `wp core install`
- [ ] Create **2 users**: 1 administrator + 1 normal user
- [ ] Admin username must **NOT** contain `admin` / `Admin` / `administrator`
- [ ] php-fpm listens on **9000** and runs in foreground
- [ ] Named volume mounted on the WordPress files dir

## 5. NGINX container

- [ ] Dockerfile from Debian/Alpine, install `nginx` + `openssl`
- [ ] Generate a **self-signed TLS certificate** for `<login>.42.fr`
- [ ] `nginx.conf`: `listen 443 ssl;`, `ssl_protocols TLSv1.2 TLSv1.3;`, `server_name <login>.42.fr;`
- [ ] `fastcgi_pass wordpress:9000;` for `.php` files
- [ ] Only container with `ports: - "443:443"`
- [ ] Run nginx in foreground (`daemon off;`)
- [ ] Mount the WordPress volume so nginx serves the static files

## 6. docker-compose.yml

- [ ] 3 services: `nginx`, `wordpress`, `mariadb`
- [ ] `build:` context pointing to each `requirements/<service>`
- [ ] One custom `networks:` (bridge) shared by all
- [ ] Two **named volumes** (no bind mounts) with `driver: local`, `driver_opts` `type: none`, `o: bind`, `device: /home/<login>/data/...`
- [ ] `env_file: .env` and/or `secrets:`
- [ ] `depends_on` ordering (mariadb → wordpress → nginx)
- [ ] `restart: always`

## 7. Makefile

- [ ] `all` / `up` → build + run via `docker compose -f srcs/docker-compose.yml up -d --build`
- [ ] `down` → stop containers
- [ ] `clean` → down + remove volumes/images
- [ ] `fclean` → clean + prune + wipe `/home/<login>/data/*`
- [ ] `re` → fclean + all
- [ ] Creates the `/home/<login>/data` dirs if missing

## 8. Documentation (mandatory for validation)

- [ ] `README.md`
  - [ ] First line, **italicized**: `*This project has been created as part of the 42 curriculum by <login>.*`
  - [ ] **Description** section
  - [ ] **Instructions** section (build / run / stop)
  - [ ] **Resources** section (docs, articles, tutorials + **how AI was used**, on which tasks/parts)
  - [ ] **Project description** section with Docker usage + design choices + comparisons:
    - [ ] Virtual Machines vs Docker
    - [ ] Secrets vs Environment Variables
    - [ ] Docker Network vs Host Network
    - [ ] Docker Volumes vs Bind Mounts
  - [ ] Written in **English**
- [ ] `USER_DOC.md` — services provided, start/stop, access site + admin panel, where credentials live, how to check services are running
- [ ] `DEV_DOC.md` — env setup from scratch (prereqs, config files, secrets), build/launch via Makefile + compose, container/volume management commands, where data is stored and how it persists

## 9. Testing before defense

- [ ] `https://<login>.42.fr` loads WordPress
- [ ] `curl -I --tlsv1.1 --tls-max 1.1 https://<login>.42.fr` fails; TLSv1.2/1.3 succeed
- [ ] Can log into `/wp-admin` with the non-admin-named administrator account
- [ ] Second (non-admin) user exists
- [ ] `docker kill` a container → it restarts automatically
- [ ] `make fclean && make` rebuilds from zero and the site still works
- [ ] Data survives `make down && make up` (volumes persist)
- [ ] `docker volume inspect` shows data under `/home/<login>/data`
- [ ] No `latest` tag anywhere: `grep -r latest srcs/`
- [ ] No password in any Dockerfile
- [ ] `git status` clean — `.env` and `secrets/` untracked
