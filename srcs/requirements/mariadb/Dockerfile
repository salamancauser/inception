# Debian 12 "bookworm" — the penultimate stable release (13 "trixie" is
# current stable). The subject forbids the floating tag: it is a moving
# target, so a build that works today can break tomorrow.
FROM debian:bookworm

# --no-install-recommends keeps the image small; clearing the apt lists in the
# SAME RUN matters — a separate RUN would leave them in the previous layer.
RUN apt-get update && apt-get install -y --no-install-recommends \
        mariadb-server \
    && rm -rf /var/lib/apt/lists/* \
    # The Debian package initialises /var/lib/mysql in its postinst, so the
    # image ships a populated data directory. Docker copies image content into
    # an empty named volume on first mount, which would hand us a datadir that
    # LOOKS initialised but has none of this project's database or users.
    # Emptying it here means the volume starts genuinely empty.
    && rm -rf /var/lib/mysql/*

COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Documentation only — EXPOSE publishes nothing. 3306 stays reachable solely
# on the internal docker network because no `ports:` entry maps it.
EXPOSE 3306

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
# Passed to the entrypoint as "$@", which ends with `exec "$@"` so mariadbd
# replaces the shell and becomes PID 1.
CMD ["mariadbd", "--user=mysql"]
