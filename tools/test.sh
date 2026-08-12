#!/bin/sh
# Checks the running stack against the subject's requirements.
#
#   ./tools/test.sh          fast, read-only checks
#   ./tools/test.sh --full   also tests crash-restart and data persistence
#                            (restarts containers; takes a couple of minutes)
#
# Run it from the project root, after `make`.

set -u

PASS=0
FAIL=0

green() { printf '\033[32m%s\033[0m' "$1"; }
red()   { printf '\033[31m%s\033[0m' "$1"; }

# check <description> <command...>  — passes if the command exits 0
check() {
	desc=$1
	shift
	printf '  %-52s' "$desc"
	if "$@" >/dev/null 2>&1; then
		green "PASS"; echo; PASS=$((PASS + 1))
	else
		red "FAIL"; echo; FAIL=$((FAIL + 1))
	fi
}

# check_not <description> <command...>  — passes if the command exits NON-zero
check_not() {
	desc=$1
	shift
	printf '  %-52s' "$desc"
	if "$@" >/dev/null 2>&1; then
		red "FAIL"; echo; FAIL=$((FAIL + 1))
	else
		green "PASS"; echo; PASS=$((PASS + 1))
	fi
}

# ---------------------------------------------------------------- config ---

[ -f srcs/.env ] || { echo "srcs/.env not found — run this from the project root"; exit 1; }
# shellcheck disable=SC1091
. ./srcs/.env

: "${DATA_PATH:=/home/$(id -un)/data}"
COMPOSE="docker compose -f srcs/docker-compose.yml"

# Works whether or not the domain is in /etc/hosts.
CURL="curl -k -s --resolve ${DOMAIN_NAME}:443:127.0.0.1"

echo
echo "Testing ${DOMAIN_NAME}  (data: ${DATA_PATH})"

# -------------------------------------------------------------- services ---
echo
echo "SERVICES"

for c in mariadb wordpress nginx; do
	check "$c is running" \
		sh -c "[ \"\$(docker inspect -f '{{.State.Running}}' $c 2>/dev/null)\" = true ]"
done

# The subject requires one daemon per container, in the foreground as PID 1.
check "mariadb runs mariadbd as PID 1" \
	sh -c "docker exec mariadb cat /proc/1/comm | grep -q '^mariadbd$'"
check "wordpress runs php-fpm as PID 1" \
	sh -c "docker exec wordpress cat /proc/1/comm | grep -q '^php-fpm'"
check "nginx runs nginx as PID 1" \
	sh -c "docker exec nginx cat /proc/1/comm | grep -q '^nginx$'"

check "restart policy is 'always' on all three" \
	sh -c "[ \"\$(docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' mariadb wordpress nginx | sort -u)\" = always ]"

# --------------------------------------------------------------- network ---
echo
echo "NETWORK"

check "443 is published" \
	sh -c "$COMPOSE ps --format '{{.Ports}}' | grep -q '0.0.0.0:443'"
check_not "3306 is NOT published" \
	sh -c "docker ps --format '{{.Ports}}' | grep -q '0.0.0.0:3306'"
check_not "9000 is NOT published" \
	sh -c "docker ps --format '{{.Ports}}' | grep -q '0.0.0.0:9000'"
check "all three share the 'inception' network" \
	sh -c "[ \"\$(docker network inspect inception -f '{{len .Containers}}')\" = 3 ]"
check "containers resolve each other by service name" \
	sh -c "docker exec nginx getent hosts wordpress"

# ------------------------------------------------------------------- tls ---
echo
echo "TLS"

check "site answers 200 over HTTPS" \
	sh -c "[ \"\$($CURL -o /dev/null -w '%{http_code}' https://${DOMAIN_NAME}/)\" = 200 ]"
check_not "TLSv1.0 is refused" \
	sh -c "$CURL --tlsv1.0 --tls-max 1.0 -o /dev/null https://${DOMAIN_NAME}/"
check_not "TLSv1.1 is refused" \
	sh -c "$CURL --tlsv1.1 --tls-max 1.1 -o /dev/null https://${DOMAIN_NAME}/"
check "TLSv1.2 is accepted" \
	sh -c "$CURL --tlsv1.2 --tls-max 1.2 -o /dev/null https://${DOMAIN_NAME}/"
check "TLSv1.3 is accepted" \
	sh -c "$CURL --tlsv1.3 -o /dev/null https://${DOMAIN_NAME}/"
check "certificate CN matches the domain" \
	sh -c "echo | openssl s_client -connect 127.0.0.1:443 -servername ${DOMAIN_NAME} 2>/dev/null | openssl x509 -noout -subject | grep -q 'CN *= *${DOMAIN_NAME}'"

# ------------------------------------------------------------- wordpress ---
echo
echo "WORDPRESS"

check "WordPress is installed" \
	sh -c "docker exec wordpress wp core is-installed --allow-root"
check "site title is '${WP_TITLE}'" \
	sh -c "$CURL https://${DOMAIN_NAME}/ | grep -qi '<title>.*${WP_TITLE}'"
check "php is executing (page references wp-content)" \
	sh -c "$CURL https://${DOMAIN_NAME}/ | grep -q 'wp-content'"
check "/wp-admin/ redirects to login" \
	sh -c "[ \"\$($CURL -o /dev/null -w '%{http_code}' https://${DOMAIN_NAME}/wp-admin/)\" = 302 ]"
check "exactly 2 users exist" \
	sh -c "[ \"\$(docker exec wordpress wp user list --allow-root --field=user_login | wc -l)\" = 2 ]"
check "an administrator exists" \
	sh -c "docker exec wordpress wp user list --allow-root --role=administrator --field=user_login | grep -q ."
check_not "admin username does NOT contain 'admin'" \
	sh -c "docker exec wordpress wp user list --allow-root --role=administrator --field=user_login | grep -qi admin"

# --------------------------------------------------------------- volumes ---
echo
echo "VOLUMES"

for v in db_data wp_files; do
	check "$v is a named volume, local driver" \
		sh -c "[ \"\$(docker volume inspect $v -f '{{.Driver}}')\" = local ]"
	check "$v is backed by ${DATA_PATH}" \
		sh -c "docker volume inspect $v -f '{{.Options.device}}' | grep -q '^${DATA_PATH}'"
done

check "database files exist on the host" \
	sh -c "[ \"\$(docker run --rm -v ${DATA_PATH}:/d debian:bookworm sh -c 'ls -A /d/mariadb | wc -l')\" -gt 0 ]"
check "wordpress files exist on the host" \
	sh -c "[ \"\$(docker run --rm -v ${DATA_PATH}:/d debian:bookworm sh -c 'ls -A /d/wordpress | wc -l')\" -gt 0 ]"

# ------------------------------------------------------------ repo rules ---
echo
echo "REPO RULES"

check_not "no 'latest' tag anywhere in srcs/" \
	grep -rq "latest" srcs/
check_not "no password in any Dockerfile" \
	sh -c "grep -rqiE 'password|passwd' srcs/requirements/*/Dockerfile"
check_not "no tail -f / sleep infinity / while true" \
	sh -c "grep -rqE 'tail -f|sleep infinity|while true' srcs/"
check_not "no host networking" \
	sh -c "grep -rq 'network_mode' srcs/"
check_not "no links:" \
	sh -c "grep -rqE '^[[:space:]]*links:' srcs/"
check "base image is a pinned debian tag" \
	sh -c "grep -hq '^FROM debian:' srcs/requirements/mariadb/Dockerfile"
check "no secrets or .env tracked by git" \
	sh -c "[ -z \"\$(git ls-files secrets/ srcs/.env)\" ]"

# ------------------------------------------------------ --full extra runs ---
if [ "${1:-}" = "--full" ]; then
	echo
	echo "CRASH RECOVERY  (restarts containers)"

	before=$(docker inspect -f '{{.RestartCount}}' nginx)
	# Not `docker kill`: docker treats that as a manual stop and deliberately
	# skips the restart policy. Making the service exit on its own is what a
	# real crash looks like.
	docker exec nginx nginx -s stop >/dev/null 2>&1
	sleep 8
	check "nginx restarted after its process exited" \
		sh -c "[ \"\$(docker inspect -f '{{.RestartCount}}' nginx)\" -gt $before ]"
	check "nginx serves again after restarting" \
		sh -c "[ \"\$($CURL -o /dev/null -w '%{http_code}' https://${DOMAIN_NAME}/)\" = 200 ]"

	echo
	echo "PERSISTENCE  (make down && make up)"

	marker="persistence-test-$$"
	docker exec wordpress wp post create --allow-root \
		--post_title="$marker" --post_status=publish --porcelain >/dev/null 2>&1

	make down >/dev/null 2>&1
	make up   >/dev/null 2>&1

	i=0
	while [ $i -lt 60 ]; do
		docker exec wordpress wp core is-installed --allow-root >/dev/null 2>&1 && break
		i=$((i + 1)); sleep 2
	done

	check "post survived down/up" \
		sh -c "docker exec wordpress wp post list --allow-root --field=post_title | grep -q '$marker'"
	check "mariadb skipped re-initialisation" \
		sh -c "docker logs mariadb 2>&1 | grep -q 'already exists — skipping'"
	check "wordpress skipped re-installation" \
		sh -c "docker logs wordpress 2>&1 | grep -q 'already installed — skipping'"

	docker exec wordpress wp post delete \
		"$(docker exec wordpress wp post list --allow-root --field=ID --post_status=publish | head -1)" \
		--force --allow-root >/dev/null 2>&1
fi

# ---------------------------------------------------------------- result ---
echo
echo "─────────────────────────────────────────────────────"
printf '  %s passed, ' "$(green "$PASS")"
if [ "$FAIL" -eq 0 ]; then
	printf '%s failed\n\n' "$(green 0)"
	exit 0
else
	printf '%s failed\n\n' "$(red "$FAIL")"
	exit 1
fi
