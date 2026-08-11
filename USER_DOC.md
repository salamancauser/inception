# Inception — User Documentation

How to run and use the infrastructure. For how it is built and how to modify
it, see [DEV_DOC.md](DEV_DOC.md).

## What this provides

A WordPress website served over HTTPS, built from three containers:

| Container   | What it does for you                                        |
| ----------- | ----------------------------------------------------------- |
| `nginx`     | Serves the site over HTTPS on port 443. The only way in.     |
| `wordpress` | Runs the WordPress code (php-fpm).                           |
| `mariadb`   | Stores the site's content — posts, pages, users, settings.   |

Only `nginx` is reachable from outside. The database and PHP processor are on
a private network with no route in from the VM or from your machine.

## Before the first start

The domain has to resolve locally. Add this line to `/etc/hosts` on the
machine whose browser you will use:

```
127.0.0.1 zzin.42.fr
```

## Starting and stopping

All commands are run from the project root.

| Command      | What happens                                                    |
| ------------ | --------------------------------------------------------------- |
| `make`       | Builds the images if needed and starts the three containers.      |
| `make down`  | Stops and removes the containers. **Your site and data survive.** |
| `make clean` | Stops, and also removes this project's volumes and images.        |
| `make fclean`| Everything `clean` does, plus deletes the site data on the host.  |
| `make re`    | `fclean` followed by a full rebuild — a completely fresh site.    |

The first `make` takes several minutes: it downloads Debian, installs the
packages and downloads WordPress. Later starts take seconds.

> `make clean` and `make fclean` **destroy your site content permanently.**
> Only `make down` is safe if you want to come back to the same site.

## Using the site

- **Website:** <https://zzin.42.fr>
- **Admin panel:** <https://zzin.42.fr/wp-admin>

Your browser will show a certificate warning the first time. This is expected:
the certificate is self-signed rather than issued by a public authority, so
the browser cannot vouch for it. The connection is still encrypted. Choose
"Advanced" → "Proceed".

Two accounts exist:

| Account         | Role          | Can do                                     |
| --------------- | ------------- | ------------------------------------------ |
| `zzin`          | Administrator | Everything — settings, themes, all content. |
| `guest`         | Author        | Write and publish their own posts only.     |

## Where the credentials live

Passwords are **not** in the repository and are not in the site's
configuration. They are files on the host, in `secrets/`:

| File                            | Contains                                |
| ------------------------------- | --------------------------------------- |
| `secrets/db_root_password.txt`  | MariaDB root password                    |
| `secrets/db_password.txt`       | Password of the WordPress database user  |
| `secrets/credentials.txt`       | Both WordPress account passwords         |

To read your WordPress login passwords:

```sh
cat secrets/credentials.txt
```

These files are listed in `.gitignore`, so they are never committed. If you
lose them, the site cannot be rebuilt with the same accounts — `make re` and
recreate them.

## Checking that everything is running

```sh
make ps
```

All three containers should show state `Up`. Expected output shape:

```
NAME        IMAGE       STATUS         PORTS
mariadb     mariadb     Up 2 minutes
nginx       nginx       Up 2 minutes   0.0.0.0:443->443/tcp
wordpress   wordpress   Up 2 minutes
```

Only `nginx` lists a port. That is correct and intended.

To watch what the services are doing, including startup problems:

```sh
make logs            # all three, follow mode, Ctrl-C to stop
docker logs mariadb  # just one
```

To confirm the site answers over HTTPS:

```sh
curl -kI https://zzin.42.fr
```

`HTTP/1.1 200 OK` (or a `301`/`302` redirect) means the whole chain works:
nginx accepted the TLS connection, passed the request to php-fpm, and
WordPress answered.

## If something is wrong

| Symptom                              | Where to look                                   |
| ------------------------------------ | ----------------------------------------------- |
| Browser cannot reach the site at all | Is the `/etc/hosts` line present? `make ps`     |
| "Error establishing a DB connection" | `docker logs mariadb`, then `docker logs wordpress` |
| A container keeps restarting         | `docker logs <name>` — it is crashing on startup |
| Site loads but has no styling        | The `wp_files` volume is empty — try `make re`   |
