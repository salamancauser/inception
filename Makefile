# The subject requires the volume data to live in /home/<login>/data on the
# host. That path follows the unix user, which differs between machines, so
# LOGIN defaults to whoever runs make and can be overridden: make LOGIN=zzin
LOGIN     ?= $(shell id -un)
DATA_PATH ?= /home/$(LOGIN)/data

# Exported so docker compose reads the same value in the volumes' driver_opts.
# A shell variable takes precedence over srcs/.env, so this always wins.
export DATA_PATH

COMPOSE := docker compose -f srcs/docker-compose.yml

all: up

# The bind-backed named volumes fail to mount if their host directory does not
# already exist, so it is created before the stack comes up.
up:
	mkdir -p $(DATA_PATH)/mariadb $(DATA_PATH)/wordpress
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

# Stop everything and drop this project's volumes and images.
clean:
	$(COMPOSE) down -v --rmi all

# Same as clean, plus wipe the data on the host. Needs sudo: the database
# files inside the volume are owned by the mysql user, not by you.
fclean: clean
	sudo rm -rf $(DATA_PATH)/mariadb $(DATA_PATH)/wordpress

re: fclean all

# --- helpers (not required by the subject, useful while debugging) ---------

logs:
	$(COMPOSE) logs -f

ps:
	$(COMPOSE) ps

.PHONY: all up down clean fclean re logs ps
