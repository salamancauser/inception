FROM debian:bookworm

# openssl generates the self-signed certificate; gettext-base provides
# envsubst, used to inject the domain name into the config at runtime
# (nginx has no notion of environment variables in its own config files).
RUN apt-get update && apt-get install -y --no-install-recommends \
        nginx \
        openssl \
        gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Debian ships a default site listening on port 80. The subject allows 443
# and nothing else, so it has to go.
RUN rm -f /etc/nginx/sites-enabled/default

# Kept out of conf.d/ on purpose: nginx includes conf.d/*.conf, and the
# unrendered template with its ${DOMAIN_NAME} placeholder is not valid config.
COPY conf/default.conf.template /etc/nginx/templates/default.conf.template
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 443

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
# `daemon off;` keeps nginx in the foreground. Its default is to fork into the
# background, which would make PID 1 exit and kill the container.
CMD ["nginx", "-g", "daemon off;"]
