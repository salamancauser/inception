# Inception — Concepts to Learn (study guide)

A learning roadmap for the 42 **Inception** project. Each section says *why it matters for the
subject*, the *key things to be able to explain at defense*, and *what to watch/read*.

YouTube links are given as search queries — channel + title — so you can pick the freshest
version of each video. Prefer videos from the last 2–3 years for Docker Compose (the `docker-compose`
→ `docker compose` v2 switch matters).


---

## Suggested order

1. Virtualization & VMs → 2. Linux service/daemon basics → 3. Docker fundamentals →
4. Dockerfiles → 5. Volumes → 6. Networking → 7. Docker Compose → 8. Secrets & env →
9. NGINX + TLS → 10. PHP-FPM & FastCGI → 11. WordPress + wp-cli → 12. MariaDB → 13. Makefile

---

## 1. Virtualization: VMs vs Containers

**Why:** the whole project runs in a VM, and the README must compare VMs and Docker.

**Must be able to explain:**
- Hypervisor (type 1 vs type 2), guest OS, hardware emulation
- A container shares the **host kernel**; a VM ships its own kernel
- Linux primitives behind containers: **namespaces** (pid, net, mnt, uts, ipc, user) and **cgroups**
- Trade-offs: isolation strength vs boot time, image size, resource cost
- Why 42 makes you run Docker *inside* a VM anyway

**Watch:**
- IBM Technology — "Containers vs VMs: What's the difference?"
- Fireship — "Docker in 100 Seconds"
- NetworkChuck — "you need to learn Virtual Machines RIGHT NOW!!"

**Read:** Docker docs → *Get Started / What is a container?*

---

## 2. Linux daemons, PID 1, foreground vs background

**Why:** the subject explicitly forbids `tail -f`, `sleep infinity`, `while true` and tells you to
"read about PID 1 and best practices for Dockerfiles".

**Must be able to explain:**
- A container lives exactly as long as its **PID 1** process
- Why daemonizing (`nginx` default, `mysqld_safe &`, `php-fpm` without `-F`) makes the container exit
- How to force foreground: `nginx -g "daemon off;"`, `php-fpm -F`, `mysqld` directly
- Signal handling / zombie reaping — why PID 1 is special (`--init`, `tini`)
- Why the "hacky patch" loops are forbidden: they fake a healthy container that runs nothing

**Watch:**
- Search: "docker PID 1 zombie process explained"
- Search: "why does my docker container exit immediately"

**Read:** Docker docs → *Best practices for writing Dockerfiles*; the `tini` README.

---

## 3. Docker fundamentals

**Must be able to explain:**
- image vs container vs layer vs registry
- `docker run / ps / exec / logs / inspect / stop / rm / rmi / system prune`
- image layering and the build cache
- why `latest` is forbidden (non-reproducible builds)
- "penultimate stable version" — e.g. Debian: if `trixie` is stable, use `bookworm`

**Watch:**
- TechWorld with Nana — "Docker Tutorial for Beginners [FULL COURSE]"
- NetworkChuck — "you need to learn Docker RIGHT NOW!!"
- freeCodeCamp — "Docker Tutorial for Beginners — full course"

---

## 4. Dockerfiles

**Must be able to explain:**
- `FROM, RUN, COPY, ADD, WORKDIR, EXPOSE, ENV, ARG, ENTRYPOINT, CMD, USER, VOLUME`
- `ENTRYPOINT` vs `CMD`, and shell form vs exec form (`CMD ["nginx","-g","daemon off;"]`)
- `ARG` (build time, ends up in history) vs `ENV` (runtime) — and why **no password** goes in either
- `.dockerignore`
- Layer minimisation: `apt-get update && apt-get install -y --no-install-recommends ... && rm -rf /var/lib/apt/lists/*`
- Entrypoint scripts: waiting for a dependency, `exec "$@"` to keep PID 1 correct

**Watch:**
- TechWorld with Nana — "Dockerfile tutorial"
- Search: "docker ENTRYPOINT vs CMD explained"

---

## 5. Volumes and persistence

**Why:** two **named volumes** are mandatory, bind mounts are explicitly **not allowed**, yet the data
must live in `/home/<login>/data`. That combination is the trickiest bit of the subject — you solve it
with a named volume declared with `driver_opts: type=none, o=bind, device=/home/<login>/data/...`.

**Must be able to explain:**
- named volume vs anonymous volume vs bind mount
- where Docker stores volumes by default (`/var/lib/docker/volumes/...`)
- why volumes are the recommended persistence mechanism (portability, permissions, backup, driver support)
- `docker volume ls / inspect / rm`, and what `docker compose down -v` destroys

**Watch:**
- TechWorld with Nana — "Docker Volumes explained in 6 minutes"
- Search: "docker named volume with driver_opts bind device"

---

## 6. Docker networking

**Why:** a `networks:` section is mandatory; `host`, `--link`, `links:` are forbidden; only NGINX
publishes a port.

**Must be able to explain:**
- bridge (default vs user-defined), host, none network drivers
- **automatic DNS between containers on a user-defined network** — this is why `fastcgi_pass wordpress:9000`
  and `DB_HOST=mariadb` work
- `EXPOSE` vs `ports:` (publishing) — 3306 and 9000 stay internal, only 443 is published
- why `network_mode: host` breaks isolation and is banned here
- why `links:` is legacy/deprecated

**Watch:**
- NetworkChuck — "Docker Networking"
- Search: "docker bridge network vs host network explained"

---

## 7. Docker Compose

**Must be able to explain:**
- `services`, `build.context`, `image`, `container_name`, `volumes`, `networks`, `env_file`,
  `depends_on`, `restart`, `secrets`
- `docker compose up -d --build`, `down`, `down -v`, `logs -f`, `ps`, `exec`
- `depends_on` only orders **startup**, not readiness — that's why your entrypoint must wait for MariaDB
- restart policies: `no` / `on-failure` / `always` / `unless-stopped`
- top-level named volumes and networks vs per-service references

**Watch:**
- TechWorld with Nana — "Docker Compose Tutorial"
- Search: "docker compose v2 tutorial 2024"

---

## 8. Secrets vs environment variables

**Why:** the README must compare them, `.env` is mandatory, Docker secrets are strongly recommended,
and any credential committed to git = project failure.

**Must be able to explain:**
- `.env` file, `env_file:`, variable substitution `${VAR}` inside compose
- env vars leak: visible in `docker inspect`, `/proc/<pid>/environ`, child processes, image history
- Docker secrets: file mounted at `/run/secrets/<name>`, tmpfs-backed, not in the image
- the `_FILE` convention (`MYSQL_ROOT_PASSWORD_FILE`) used by DB entrypoints
- `.gitignore` for `srcs/.env` and `secrets/`

**Watch:**
- Search: "docker secrets vs environment variables"
- Search: "docker compose secrets tutorial"

---

## 9. NGINX, HTTPS and TLS

**Must be able to explain:**
- what a reverse proxy is and why NGINX is the single entrypoint
- `server`, `listen`, `server_name`, `root`, `index`, `location` blocks
- TLS handshake basics: certificate, public/private key, CA, why a **self-signed** cert triggers a
  browser warning (and why that's expected here)
- `openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ... -out ...`
- `ssl_protocols TLSv1.2 TLSv1.3;` — and why older TLS/SSL versions are disabled
- how to verify: `openssl s_client -connect <login>.42.fr:443 -tls1_2`

**Watch:**
- Search: "nginx reverse proxy explained"
- Search: "TLS handshake explained" (Practical Networking has an excellent SSL/TLS series)
- Search: "self signed certificate openssl nginx tutorial"

---

## 10. PHP-FPM and FastCGI

**Why:** the WordPress container runs php-fpm *without* nginx; NGINX talks to it over the network.

**Must be able to explain:**
- CGI → FastCGI → PHP-FPM: why a persistent process pool beats spawning a process per request
- `www.conf` pool config: `listen = 9000` (TCP, not a unix socket — it must cross containers)
- the NGINX side: `fastcgi_pass wordpress:9000; fastcgi_param SCRIPT_FILENAME ...; include fastcgi_params;`
- why both containers need the WordPress files (nginx serves static assets, php-fpm executes PHP)

**Watch:**
- Search: "php-fpm and nginx how they work together"
- Search: "what is FastCGI"

---

## 11. WordPress and wp-cli

**Must be able to explain:**
- what `wp-config.php` contains (DB host/name/user/password, salts)
- `wp core download`, `wp config create`, `wp core install`, `wp user create`
- why the install is scripted in the entrypoint instead of clicking through the web installer
- the two required users, and the forbidden admin usernames
- idempotency: `wp core is-installed` guard so restarts don't reinstall

**Watch:**
- Search: "wp-cli tutorial install wordpress command line"

---

## 12. MariaDB

**Must be able to explain:**
- MariaDB vs MySQL
- `/var/lib/mysql` = the data directory (this is what the volume protects)
- initialising a DB: `mysql_install_db`, then create database/user/grants
- `bind-address = 0.0.0.0` so the WordPress container can reach it
- root user vs the WordPress user, and least privilege
- why port 3306 is never published to the host

**Watch:**
- Search: "mariadb docker container from scratch tutorial"
- Search: "SQL basics for beginners" (only if SQL is new to you)

---

## 13. Makefile

**Must be able to explain:**
- targets, prerequisites, recipes, `.PHONY`
- why every rule here is phony (no file is produced)
- what `fclean` must destroy: containers, images, volumes, and the host data dirs

**Watch:**
- Search: "makefile tutorial for beginners"

---

## Playlist shortlist (if you only have one day)

1. Fireship — *Docker in 100 Seconds* (2 min, mental model)
2. TechWorld with Nana — *Docker Tutorial for Beginners full course* (~3 h, the backbone)
3. TechWorld with Nana — *Docker Volumes explained in 6 minutes*
4. NetworkChuck — *Docker Networking*
5. Search — *php-fpm and nginx how they work together*
6. Search — *self signed certificate openssl nginx*
7. Search — *wp-cli install wordpress command line*

---

## Written references

- Docker docs — Get Started, Dockerfile reference, Compose file reference, Volumes, Networking, Secrets
- Docker docs — *Best practices for writing Dockerfiles*
- NGINX docs — *Configuring HTTPS servers*, *ngx_http_fastcgi_module*
- MariaDB Knowledge Base — *Getting Installing and Upgrading MariaDB*
- WordPress — *wp-cli handbook*, *Editing wp-config.php*
- `man 5 my.cnf`, `man nginx`, `man make`

---

## Defense self-check (answer out loud, without notes)

- What is the difference between a Docker image and a container?
- Why is `network: host` forbidden here, and what would break?
- Why is a named volume preferred to a bind mount, and how did you still get the data into `/home/<login>/data`?
- What happens if PID 1 exits? Why can't I just use `tail -f /dev/null`?
- Where is your DB password stored, and who can read it at each stage (build, image, runtime, git)?
- How does NGINX reach WordPress by name, with no `links:`?
- Which TLS versions do you accept and how would you prove it from the CLI?
- What does `make fclean` delete, exactly?
