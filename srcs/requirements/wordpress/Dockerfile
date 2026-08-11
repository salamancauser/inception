FROM debian:bookworm

# php8.2 is what bookworm ships. NO nginx here — this container runs php-fpm
# only; the web server lives in its own container, one service per container.
# mariadb-client is for the readiness probe in the entrypoint.
RUN apt-get update && apt-get install -y --no-install-recommends \
        php8.2-fpm \
        php8.2-mysql \
        php8.2-curl \
        php8.2-gd \
        php8.2-mbstring \
        php8.2-xml \
        php8.2-zip \
        mariadb-client \
        curl \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# wp-cli, pinned to a release. WordPress is installed from a script rather
# than by clicking through the web installer, because a container has to come
# up unattended.
RUN curl -fsSL -o /usr/local/bin/wp \
        https://github.com/wp-cli/wp-cli/releases/download/v2.11.0/wp-cli-2.11.0.phar \
    && chmod +x /usr/local/bin/wp

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /var/www/html
EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
# -F = stay in the foreground. Without it php-fpm daemonises, PID 1 exits,
# and the container dies immediately after starting.
CMD ["php-fpm8.2", "-F"]
