LOGIN   := zzin
DATA    := /home/$(LOGIN)/data
COMPOSE := docker compose -f srcs/docker-compose.yml

all: up

# Create the host folders backing the two named volumes, then build and run.
up:
	mkdir -p $(DATA)/mariadb $(DATA)/wordpress
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

# Stop everything and drop this project's volumes and images.
clean:
	$(COMPOSE) down -v --rmi all

# Same as clean, plus wipe the data on the host.
fclean: clean
	sudo rm -rf $(DATA)/mariadb $(DATA)/wordpress

re: fclean all

.PHONY: all up down clean fclean re
