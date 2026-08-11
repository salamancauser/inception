# Inception — learning resources by concept

Ordered the way you should learn them. One video + one document per concept, no filler.

---

## 1. What a container actually is

The foundation. Get this wrong and everything else is cargo-culting.

**Video — [Containers From Scratch • Liz Rice • GOTO 2018](https://www.youtube.com/watch?v=8fi7uSYlOdc)** · 43 min
She live-codes a working container in ~30 lines of Go. Namespaces and cgroups stop being buzzwords and become things you watched someone type. This single video writes your README's "Virtual Machines vs Docker" section for you.
Code: [github.com/lizrice/containers-from-scratch](https://github.com/lizrice/containers-from-scratch)

**Shorter alternative — [Containers vs VMs: What's the difference?](https://www.youtube.com/watch?v=cjXI-yxqGTI)** (IBM Technology) · ~8 min lightboard.

**Doc —** [What is a container?](https://www.ibm.com/think/topics/containers) (IBM) — clean written summary of the same ideas.

---

## 2. Docker fundamentals — images, layers, Dockerfile, volumes, Compose

**Video — [Docker Tutorial for Beginners, full course](https://www.youtube.com/watch?v=3c-iBn73dDE)** (TechWorld with Nana) · 3 h
Watch the container/image, Dockerfile, volumes and docker-compose sections. Skip the Node.js demo app and AWS deploy at the end. She's a Docker Captain and explains *why*, which is what the defense tests.

**Docs (read, don't skim):**

- [Building best practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/) — the subject literally tells you to read this
- [Dockerfile reference](https://docs.docker.com/reference/dockerfile/) — every instruction, with the exec-form vs shell-form distinction
- [Compose file reference](https://docs.docker.com/reference/compose-file/) — your `docker-compose.yml` bible

---

## 3. PID 1, daemons and signals

The concept the project is really testing. **There is no good video on this** — it's an article topic. Read all three, they're short.

- [Why Your Dockerized Application Isn't Receiving Signals](https://hynek.me/articles/docker-signals/) — Hynek Schlawack. The clearest explanation of exec-form vs shell-form and why `exec` matters in entrypoint scripts.
- [PID 1 Signal Handling in Docker](https://petermalmgren.com/signal-handling-docker/) — Peter Malmgren. What SIGTERM does and why your container ignores `docker stop`.
- [Choosing Between RUN, CMD and ENTRYPOINT](https://www.docker.com/blog/docker-best-practices-choosing-between-run-cmd-and-entrypoint/) — official Docker blog.

After these you can explain exactly why `tail -f /dev/null` is banned.

---

## 4. Docker networking

**Video — [Docker Networking Tutorial, ALL Network Types explained](https://www.youtube.com/watch?v=5grbXvV_DSk)**
Covers bridge vs host vs none. You only need bridge — but you must be able to say why `network_mode: host` is forbidden.

**Doc —** Docker docs → *Networking overview* and the `networks` section of the [Compose file reference](https://docs.docker.com/reference/compose-file/). The key fact: on a user-defined bridge network, containers resolve each other by **service name** via Docker's embedded DNS. That's why `links:` is obsolete.

---

## 5. Volumes vs bind mounts

**Doc — [Volumes](https://docs.docker.com/engine/storage/volumes/)** (Docker docs)
This is a README requirement, so read the volumes-vs-bind-mounts comparison carefully. Note the rule that matters for you: the top-level `volumes:` key always declares *named volumes*; a bind mount has no name and cannot be declared there.

---

## 6. Secrets vs environment variables

**Doc — [Use secrets in Docker Compose](https://docs.docker.com/compose/how-tos/use-secrets/)**
Also a README requirement. The short version: env vars are visible in `docker inspect`, in `/proc`, and leak into child processes; secrets are mounted as files under `/run/secrets/` and never enter the image or the process environment.

---

## 7. TLS / HTTPS

**Video — [TLS Handshake Explained](https://www.youtube.com/watch?v=86cQJ0MMses)** (Computerphile) · ~15 min — the clearest short explanation.
**Longer — [TLS Handshake: EVERYTHING that happens when you visit an HTTPS website](https://www.youtube.com/watch?v=ZkL10eoG1PY)**

**Docs:**

- [What happens in a TLS handshake?](https://www.cloudflare.com/learning/ssl/what-happens-in-a-tls-handshake/) — Cloudflare Learning Center
- [ngx_http_ssl_module](http://nginx.org/en/docs/http/ngx_http_ssl_module.html) — where `ssl_protocols TLSv1.2 TLSv1.3;` is documented

---

## 8. NGINX + php-fpm (FastCGI)

**Video — [How Nginx and PHP-FPM turn a web request into code](https://www.youtube.com/watch?v=lh4RnczaATI)**
Why nginx physically cannot execute PHP, and what FastCGI is. Most students fail to explain this at defense.

**Docs:**

- [How to Configure PHP-FPM with NGINX](https://www.digitalocean.com/community/tutorials/php-fpm-nginx) — DigitalOcean
- [ngx_http_fastcgi_module](http://nginx.org/en/docs/http/ngx_http_fastcgi_module.html) — `fastcgi_pass`, `fastcgi_param`

Note for Inception: nginx and php-fpm are in **different containers**, so you use a TCP socket (`fastcgi_pass wordpress:9000;`), not a unix socket like most tutorials show.

---

## 9. WordPress & MariaDB

- [WP-CLI handbook](https://make.wordpress.org/cli/handbook/) — install and configure WordPress from a script instead of clicking through the web installer. Essential for a non-interactive container.
- [MariaDB Knowledge Base](https://mariadb.com/kb/en/) — `CREATE DATABASE`, `CREATE USER`, `GRANT`, and how the data directory initialises on first boot.

---

## 10. Makefiles

**[Makefile Tutorial by Example](https://makefiletutorial.com/)** — the standard reference. You only need targets, prerequisites and `.PHONY`.

---

## Forums & communities

| Where | Best for |
|---|---|
| [Docker Community Forums](https://forums.docker.com/) | "my container exits immediately", build and compose problems |
| [Docker Community Slack](https://www.docker.com/community/) | quick real-time questions, topic channels |
| [Stack Overflow](https://stackoverflow.com/questions/tagged/docker) — tags `docker`, `docker-compose`, `php-fpm` | specific error messages; search before posting |
| [Server Fault](https://serverfault.com/) | nginx, TLS and MariaDB *configuration* questions — better fit than Stack Overflow |
| [r/docker](https://www.reddit.com/r/docker/) | conceptual "am I doing this right" questions |
| Your campus Slack / Discord + peers | **the highest-value one.** The subject weights peer review explicitly, and peers share your exact environment and evaluator |

---

## Reference implementations

Read them for *shape*, then close the tab and write your own. Your evaluator can Google these too.

- [mcombeau/inception](https://github.com/mcombeau/inception) — clean, and the README explains its own decisions
- [42 Inception TIPS](https://tuto.grademe.fr/inception/) — French, most complete step-by-step
- [Inception guide (42 project) — Part I](https://medium.com/@ssterdev/inception-guide-42-project-part-i-7e3af15eb671)
- [vbachele/Inception](https://github.com/vbachele/Inception)

---

## Minimum viable path

If you only have time for four things:

1. Liz Rice, *Containers From Scratch* — 43 min
2. Nana's course, the Dockerfile + volumes + compose sections — ~1 h
3. The Hynek article on signals — 10 min
4. Docker's *Building best practices* page — 20 min

That's roughly 2 hours 15 and covers every concept the defense asks about.
