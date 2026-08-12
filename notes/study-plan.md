# Inception — Study Plan

The system for getting defense-ready. Written to survive a laptop change:
everything needed is either in this repo or listed below.

Companion page (same content as Session 1, nicer to read):
<https://claude.ai/code/artifact/344ee69d-8e3a-428a-aa08-7c7b906fb052>

---

## Where I am

- [ ] Session 1 — What a container is
- [ ] Session 2 — Dockerfiles
- [ ] Session 3 — Entrypoints & PID 1
- [ ] Session 4 — Compose, networks, volumes, secrets
- [ ] Session 5 — nginx, TLS, php-fpm, WordPress, MariaDB
- [ ] Session 6 — Dress rehearsal
- [ ] Solo rebuild (optional but strongly recommended)

Drill score from Session 1: __ / 8 answered before opening.

Questions I could not answer: ______________________________________

---

## Handoff — read this first if you are a fresh Claude session

Context that is not in the repo:

- **The project is finished, built, and verified working.** It passes all 38
  checks in `tools/test.sh`. Do not rewrite, refactor or "improve" the code.
  The remaining work is comprehension, not implementation.
- **The student had never used Docker before this project.** The code was
  written with heavy assistance. The defense is therefore the risk, not the
  build.
- **Tight deadline.** Do not pad. An explicit "do NOT do this" list is part of
  every session — the 3-hour tutorial, forums, and reading other repos are
  time sinks at this stage and should be named as such.
- **Goal is passing the 42 defense**, nothing more.

The method that works, established in session 1:

1. **Teach against their own running stack**, not generic tutorials. Run the
   commands first, paste the *real* output into the plan. Never write "you
   should see roughly…" — verify it.
2. **~2 hours per session**, in three blocks: short input (~30 min), long
   hands-on (~60 min), then a drill (~25 min).
3. **End every session with 8 questions** answered aloud without notes, each
   mapped back to the exercise that proves it. The score is the handoff signal
   for sizing the next session.
4. **Correct wrong mental models explicitly** rather than talking around them.
5. Deliver as an Artifact page *and* append it to this file, so it survives a
   machine change.

Before starting a session, ask for: the previous drill score, and which
questions were missed. Size the next session from that — a 7–8 means merge and
compress; a low score means re-do part of the previous session first.

Sessions 2–6 below are outlines only. Session 1 is the worked example of the
format to follow.

---

## Setting up on a new laptop

The repo carries everything, including `srcs/.env` and `secrets/` — so no
config needs recreating. Only the machine needs preparing.

```sh
git clone git@github.com:salamancauser/inception.git
cd inception

# 1. Docker (Debian/Ubuntu)
sudo apt-get update
sudo apt-get install -y docker.io docker-compose-v2 docker-buildx
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
```

Then **log out and back in** — group membership is fixed at login, so a new
terminal tab is not enough. On WSL, run `wsl --shutdown` from Windows
PowerShell and reopen.

```sh
# 2. Verify
docker run hello-world          # must work without sudo

# 3. Domain resolution
echo "127.0.0.1 zzin.42.fr" | sudo tee -a /etc/hosts
```

On WSL, also add `127.0.0.1 zzin.42.fr` to
`C:\Windows\System32\drivers\etc\hosts` as Administrator — the browser is a
Windows process and does not read WSL's `/etc/hosts`.

```sh
# 4. Build and verify
make
./tools/test.sh                 # expect 38 passed, 0 failed
```

`DATA_PATH` derives from `id -un` at runtime, so the volume path follows
whatever user you are on that machine. Nothing to edit.

---

## The six sessions

| # | Focus | Time |
| - | ----- | ---- |
| 1 | What a container actually is | 2 h |
| 2 | Dockerfiles — read my own three, line by line | 2 h |
| 3 | Entrypoints & PID 1 — `exec "$@"`, signals, idempotency | 2 h |
| 4 | Compose, networks, volumes, secrets | 2 h |
| 5 | nginx + TLS + php-fpm + WordPress + MariaDB | 2 h |
| 6 | Dress rehearsal — `tools/test.sh`, eval sheet out loud | 1.5 h |

Sessions 2 and 3 carry the most weight: Dockerfiles and entrypoints are where
evaluators concentrate, and where every forbidden practice lives. Session 6 is
not optional — it is the only one that rehearses *delivery* rather than
knowledge.

If Session 1's drill scores 7–8 of 8, sessions 2+3 merge and 4+5 compress,
giving four sessions total.

---

## Session 1 — What a container actually is

**Goal:** explain the running stack without notes. ~2 h 05 m.

Start the stack first: `make ps` — all three must be `Up`. If not, `make`.

### Block 1 — Watch & read (30 min)

| What | Where | Watch for |
| ---- | ----- | --------- |
| Containers vs VMs: What's the difference? (~8 min) | IBM Technology, <https://www.youtube.com/watch?v=cjXI-yxqGTI> | **Where the kernel sits** in each diagram. That is the whole answer. |
| Docker in 100 Seconds (~2 min) | Fireship — search that exact title | Vocabulary only: image, container, Dockerfile, layer. |
| README.md → "Virtual Machines vs Docker", then "Docker Volumes vs Bind Mounts" (~10 min) | this repo | Read aloud. This is the text being defended. |

Optional if time allows: Liz Rice, *Containers From Scratch* (43 min,
<https://www.youtube.com/watch?v=8fi7uSYlOdc>). Best explanation that exists,
not required to pass.

### The mental-model correction

"Docker means other people don't have to install my dependencies" is the
*benefit*, not the *mechanism* — and the defense asks about the mechanism.

A container is a **normal process running on the host's kernel**, fenced off
with namespaces (its own filesystem, process tree, network) and limited with
cgroups. Shipping dependencies is a consequence of packaging that filesystem.

A VM boots its own kernel and emulates hardware. A container does neither.
Every other difference — fast start, small images, weaker isolation — follows
from that one fact.

### Block 2 — Prove it on the machine (60 min)

Type these; don't just read. Outputs below are real.

**A. What is running**

```sh
docker ps
```

Only nginx shows `0.0.0.0:443->443/tcp`. The other two show a bare port with
no arrow: reachable inside the private network, unreachable from the host.
That is "nginx is the only entry point", visible in one column.

**B. The demo that settles VM vs container**

```sh
uname -r                      # host
docker exec nginx uname -r    # container
```

Both print `6.18.33.2-microsoft-standard-WSL2` — identical. The container
never booted a kernel; it uses the host's. A VM would print something else.
*If only one command is remembered from this session, it is this one.*

**C. …but a different operating system**

```sh
cat /etc/os-release | head -1
docker exec nginx cat /etc/os-release | head -1
```

Host says Ubuntu, container says `Debian GNU/Linux 12 (bookworm)`. Hold B and
C together: same kernel, different distribution. An "OS" here is just a
filesystem of programs and libraries. That is why images are ~200 MB, not ~2 GB.

**D. One service per container**

```sh
docker exec nginx ps ax
docker exec mariadb cat /proc/1/comm      # mariadbd
docker exec wordpress cat /proc/1/comm    # php-fpm8.2
docker exec nginx cat /proc/1/comm        # nginx
```

The host runs 46 processes; the mariadb container runs 3. No init, no cron, no
ssh — one daemon as PID 1. A container lives exactly as long as its PID 1.

**E. Image vs container**

```sh
docker images
```

`mariadb 524MB`, `wordpress 584MB`, `nginx 212MB`, `debian 185MB`. An image is
an inert template on disk; a container is one running instance of it. All
three were built `FROM` the same Debian base, which Docker stores once.

**F. How nginx finds WordPress with no IP**

```sh
docker exec nginx getent hosts wordpress     # 172.19.0.3  wordpress
docker exec wordpress getent hosts mariadb   # 172.19.0.2  mariadb
```

Docker runs a DNS server on the user-defined network; the compose service name
is the hostname. Hence `fastcgi_pass wordpress:9000;`, and hence `links:` is
obsolete and forbidden.

**G. Where the data really lives**

```sh
docker volume inspect db_data
```

Read `Options.device` → `/home/<login>/data/mariadb`. **`Mountpoint` is
misleading** — it shows Docker's internal path. This is how "named volume" and
"data in /home/\<login\>/data" are satisfied at once. Expect to be asked.

**H. Watch a container start from nothing**

```sh
docker logs mariadb | head -20
docker logs wordpress | head -20
```

Find the `[mariadb]` and `[wordpress]` lines — my own entrypoints narrating
first boot. Run again after a restart: they say "skipping", because the guards
detect existing state.

**I. Go inside**

```sh
docker exec -it nginx bash
  ls /etc/nginx/conf.d/
  cat /etc/nginx/conf.d/default.conf
  ls /var/www/html | head
  exit
```

The WordPress files are visible from inside nginx — same volume mounted in
both. nginx serves static assets; only `.php` goes to php-fpm.

### Block 3 — Defense drill (25 min)

Answer aloud, no notes, **before** checking. Score out of 8.

1. Difference between an image and a container? *(E)*
2. How is a container different from a VM? *(B)*
3. Host is Ubuntu — why does the container say Debian? *(B+C)*
4. What is PID 1 and why does it matter? *(D)*
5. Why is `tail -f /dev/null` forbidden as a command?
6. How does nginx reach WordPress without an IP? *(F)*
7. Where is the DB data, and what does `make down` do to it? *(G)*
8. Why three containers instead of one? *(D)*

Answers are in `notes/study-guide.md` and in `README.md`. Question 5:
because it keeps PID 1 alive while the real service may be dead — the
container looks healthy, `restart: always` never fires, crashes are invisible.

### Do NOT do in session 1

- The 3-hour Docker course. ~10 minutes of video is enough today.
- Forums (Stack Overflow, r/docker, Discord). They are for specific errors.
  Nothing is broken. Zero value now.
- Reading other students' Inception repos.
- Dockerfile syntax, TLS internals, php-fpm tuning — later sessions.
- Rewriting any code. It works and it is committed.

### Done when

1. Can explain why `uname -r` matches inside and outside, and why that single
   fact separates a container from a VM.
2. Can point at `docker ps` and say why only nginx publishes a port.
3. Can say what PID 1 is and what happens when it exits.
4. Scored at least 6 of 8 on the drill before checking.

---

## Solo rebuild (after session 6)

Rebuilding from memory is the strongest preparation — the defense asks *why
did you do X*, and choices are only truly owned when made.

**Do not delete the working version. Branch it:**

```sh
git switch -c solo-rebuild
rm -rf srcs/
```

Rebuild from an empty `srcs/`. When genuinely stuck, peek at **one file**:

```sh
git show main:srcs/requirements/nginx/Dockerfile
```

**Pass condition:** `./tools/test.sh` returns 38/38. Build in dependency order
— mariadb, then wordpress, then nginx — running the script after each.

**Keep a list of every file that needed a peek.** That list is the weak spot,
and it is what session 6 should drill.

**Compressed version (~3 h)** if the deadline is tight — rebuild only these
five, and leave the Dockerfiles alone. This is where defense questions
concentrate:

```
srcs/requirements/mariadb/tools/entrypoint.sh
srcs/requirements/wordpress/tools/entrypoint.sh
srcs/requirements/nginx/tools/entrypoint.sh
srcs/requirements/nginx/conf/default.conf.template
srcs/docker-compose.yml
```

Do this *after* session 6, not instead of it. Rebuilding teaches the material;
the rehearsal teaches delivery under questioning.

---

## Known open item

`docker images` shows the built images tagged `latest`, because `image: mariadb`
in `docker-compose.yml` carries no tag. The subject's ban on `latest` targets
the pulled base image — `FROM debian:bookworm` is correctly pinned — but a
strict evaluator running `docker images` may question it. One-line fix in
`docker-compose.yml` if desired.
