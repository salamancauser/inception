#!/bin/sh
# Wait for the database, install WordPress if it is not installed yet, then
# hand over to php-fpm. Re-running this must be harmless.
set -eu

WP_PATH=/var/www/html

# php-fpm's runtime directory lives on tmpfs and is gone on every start.
mkdir -p /run/php

DB_PASSWORD="$(cat /run/secrets/db_password)"
# credentials holds WP_ADMIN_PASSWORD= and WP_USER_PASSWORD= as KEY=value.
. /run/secrets/credentials

# `depends_on` only orders container STARTUP — it does not wait for MariaDB to
# be ready to accept queries. MariaDB's first boot initialises its system
# tables, which takes seconds. Without this loop WordPress races it and dies.
echo "[wordpress] waiting for ${MYSQL_HOST} to accept connections..."
until mariadb-admin ping \
        --host="${MYSQL_HOST}" \
        --user="${MYSQL_USER}" \
        --password="${DB_PASSWORD}" \
        --silent >/dev/null 2>&1; do
	sleep 2
done
echo "[wordpress] database is up"

cd "$WP_PATH"

# wp-config.php lives on the named volume, so this only runs on a fresh volume.
if [ ! -f wp-config.php ]; then
	echo "[wordpress] downloading WordPress ${WP_VERSION}"
	wp core download --version="${WP_VERSION}" --allow-root

	echo "[wordpress] writing wp-config.php"
	wp config create --allow-root \
		--dbname="${MYSQL_DATABASE}" \
		--dbuser="${MYSQL_USER}" \
		--dbpass="${DB_PASSWORD}" \
		--dbhost="${MYSQL_HOST}"
else
	echo "[wordpress] wp-config.php already present"
fi

# The real idempotency guard: asks the DATABASE whether the tables exist,
# rather than trusting a file on disk.
if wp core is-installed --allow-root 2>/dev/null; then
	echo "[wordpress] already installed — skipping"
else
	echo "[wordpress] installing site '${WP_TITLE}'"
	wp core install --allow-root \
		--url="https://${DOMAIN_NAME}" \
		--title="${WP_TITLE}" \
		--admin_user="${WP_ADMIN_USER}" \
		--admin_password="${WP_ADMIN_PASSWORD}" \
		--admin_email="${WP_ADMIN_EMAIL}" \
		--skip-email

	# The subject requires exactly two users: one administrator (whose name
	# must not contain "admin") and one ordinary user.
	echo "[wordpress] creating second user '${WP_USER}'"
	wp user create "${WP_USER}" "${WP_USER_EMAIL}" --allow-root \
		--role=author \
		--user_pass="${WP_USER_PASSWORD}"
fi

# The volume is mounted as root; php-fpm workers run as www-data and must be
# able to read the files (and write, for uploads).
chown -R www-data:www-data "$WP_PATH"

exec "$@"
