#!/bin/sh
# Generate a self-signed certificate on first boot, render the config with the
# domain name from the environment, then hand over to nginx.
set -eu

CERT_DIR=/etc/nginx/ssl

if [ ! -f "$CERT_DIR/inception.crt" ]; then
	echo "[nginx] generating self-signed certificate for ${DOMAIN_NAME}"
	mkdir -p "$CERT_DIR"
	# -nodes: leave the key unencrypted, otherwise nginx would block on
	# startup waiting for a passphrase nobody can type into a container.
	openssl req -x509 -nodes \
		-days 365 \
		-newkey rsa:2048 \
		-keyout "$CERT_DIR/inception.key" \
		-out "$CERT_DIR/inception.crt" \
		-subj "/C=MA/ST=Khouribga/L=Khouribga/O=42/OU=1337/CN=${DOMAIN_NAME}" \
		2>/dev/null
	chmod 600 "$CERT_DIR/inception.key"
else
	echo "[nginx] certificate already present"
fi

# Substitute ONLY ${DOMAIN_NAME}. The explicit variable list is essential:
# a bare `envsubst` would also eat $uri, $args and $document_root — nginx's
# own runtime variables — and silently replace them with empty strings.
echo "[nginx] rendering config for ${DOMAIN_NAME}"
envsubst '${DOMAIN_NAME}' \
	< /etc/nginx/templates/default.conf.template \
	> /etc/nginx/conf.d/default.conf

# Fail loudly at startup rather than serving a half-broken config.
nginx -t

exec "$@"
