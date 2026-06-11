INVENTORY ?= inventory.yml
EXAMPLE_INVENTORY ?= inventory.example.yml
PLAYBOOK ?= playbooks/minecraft.yml
LIMIT ?= minecraft_servers
CONFIRM_NUKE ?= false

.PHONY: help setup sync collections inventory syntax-check syntax-check-example ping ping-password deploy deploy-password stop stop-password restart restart-password nuke nuke-password

help:
	@printf '%s\n' \
		'Targets:' \
		'  make setup                 Install Python deps and Ansible collections' \
		'  make inventory             Create inventory.yml from inventory.example.yml if missing' \
		'  make syntax-check          Syntax-check the playbook with inventory.yml' \
		'  make syntax-check-example  Syntax-check the playbook with inventory.example.yml' \
		'  make ping                  Ping hosts in the minecraft_servers group' \
		'  make ping-password         Ping hosts and prompt for the SSH password' \
		'  make deploy                Deploy the Minecraft server' \
		'  make deploy-password       Deploy and prompt for SSH/sudo passwords' \
		'  make stop                  Stop and remove the Minecraft container stack' \
		'  make stop-password         Stop with SSH/sudo password prompts' \
		'  make restart               Restart the Minecraft container stack' \
		'  make restart-password      Restart with SSH/sudo password prompts' \
		'  make nuke CONFIRM_NUKE=true' \
		'                              Stop Minecraft and delete server data' \
		'  make nuke-password CONFIRM_NUKE=true' \
		'                              Nuke with SSH/sudo password prompts' \
		'' \
		'Variables:' \
		'  INVENTORY=path/to/inventory.yml' \
		'  PLAYBOOK=path/to/playbook.yml' \
		'  LIMIT=host-or-group' \
		'  CONFIRM_NUKE=true'

setup: sync collections

sync:
	uv sync

collections:
	uv run ansible-galaxy collection install -r requirements.yml

inventory:
	@if [ -f "$(INVENTORY)" ]; then \
		printf '%s\n' "$(INVENTORY) already exists"; \
	else \
		cp "$(EXAMPLE_INVENTORY)" "$(INVENTORY)"; \
		printf '%s\n' "Created $(INVENTORY). Edit it before deploying."; \
	fi

syntax-check:
	uv run ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --syntax-check

syntax-check-example:
	uv run ansible-playbook -i "$(EXAMPLE_INVENTORY)" "$(PLAYBOOK)" --syntax-check

ping:
	uv run ansible -i "$(INVENTORY)" "$(LIMIT)" -m ping

ping-password:
	uv run ansible -i "$(INVENTORY)" "$(LIMIT)" -m ping --ask-pass

deploy:
	uv run ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)"

deploy-password:
	uv run ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --ask-pass --ask-become-pass

stop:
	uv run ansible-playbook -i "$(INVENTORY)" playbooks/stop.yml

stop-password:
	uv run ansible-playbook -i "$(INVENTORY)" playbooks/stop.yml --ask-pass --ask-become-pass

restart:
	uv run ansible-playbook -i "$(INVENTORY)" playbooks/restart.yml

restart-password:
	uv run ansible-playbook -i "$(INVENTORY)" playbooks/restart.yml --ask-pass --ask-become-pass

nuke:
	uv run ansible-playbook -i "$(INVENTORY)" playbooks/nuke.yml -e "minecraft_confirm_nuke=$(CONFIRM_NUKE)"

nuke-password:
	uv run ansible-playbook -i "$(INVENTORY)" playbooks/nuke.yml -e "minecraft_confirm_nuke=$(CONFIRM_NUKE)" --ask-pass --ask-become-pass
