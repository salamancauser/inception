#!/bin/sh
# Initialise the database on first boot, then hand the container over to
# mariadbd. Safe to re-run: everything below is guarded.
set -eu

DATADIR=/var/lib/mysql

# The socket directory lives on tmpfs, so it is gone on every start.
mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld

# Passwords arrive as files under /run/secrets, never as env vars.
DB_ROOT_PASSWORD="$(cat /run/secrets/db_root_password)"
DB_PASSWORD="$(cat /run/secrets/db_password)"

# Two independent guards. The system tables and this project's database are
# created by different steps and can legitimately exist without each other,
# so checking only one of them gets this wrong.

if [ -d "$DATADIR/mysql" ]; then
	echo "[mariadb] system tables present — skipping datadir init"
else
	echo "[mariadb] empty data directory — initialising system tables"
	mariadb-install-db --user=mysql --datadir="$DATADIR" --skip-test-db >/dev/null
fi

# Keyed on OUR database, not on the generic mysql directory: a datadir can be
# fully initialised by Debian and still contain nothing this project needs.
if [ -d "$DATADIR/${MYSQL_DATABASE}" ]; then
	echo "[mariadb] database '${MYSQL_DATABASE}' already exists — skipping"
else
	echo "[mariadb] creating database '${MYSQL_DATABASE}' and user '${MYSQL_USER}'"
	# --bootstrap runs this SQL with no networking and no listening socket,
	# so there is no window where the server is up without a root password.
	mariadbd --user=mysql --bootstrap <<-EOF
		USE mysql;
		FLUSH PRIVILEGES;

		ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
		DELETE FROM mysql.user WHERE User = '';
		DROP DATABASE IF EXISTS test;

		CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`
		    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

		-- '%' = any host. The wordpress container gets a different IP on
		-- every restart, so pinning a host here would break on reboot.
		CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
		GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';

		FLUSH PRIVILEGES;
	EOF

	echo "[mariadb] initialisation complete"
fi

# exec replaces this shell instead of forking, so mariadbd inherits PID 1 and
# receives SIGTERM directly from `docker stop`. Without exec, the shell stays
# PID 1, ignores the signal, and docker kills the container after 10s.
exec "$@"
