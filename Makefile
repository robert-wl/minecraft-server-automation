INVENTORY ?= inventory.yml
EXAMPLE_INVENTORY ?= inventory.example.yml
PLAYBOOK ?= playbooks/minecraft.yml
LIMIT ?= minecraft_servers
CONFIRM_NUKE ?= false
VAULT_FILE ?= group_vars/minecraft_servers/vault.yml
VAULT_ARGS = $(if $(wildcard $(VAULT_FILE)),--ask-vault-pass,)

.PHONY: help setup sync collections inventory lock-check lint check install-hooks syntax-check syntax-check-example vault-create vault-edit vault-check ping deploy pull-data stop restart nuke

help:
	@printf '%s\n' \
		'Targets:' \
		'  make setup                 Install Python deps and Ansible collections' \
		'  make lint                  Run YAML, syntax, and Ansible lint checks' \
		'  make check                 Run lockfile and lint checks' \
		'  make install-hooks         Install pre-commit hooks' \
		'  make inventory             Create inventory.yml from inventory.example.yml if missing' \
		'  make syntax-check          Syntax-check the playbook with inventory.yml' \
		'  make syntax-check-example  Syntax-check the playbook with inventory.example.yml' \
		'  make vault-create          Create encrypted Ansible Vault vars for sudo' \
		'  make vault-edit            Edit encrypted Ansible Vault vars' \
		'  make vault-check           Check Vault defines ansible_become_password' \
		'  make ping                  Ping hosts in the minecraft_servers group' \
		'  make deploy                Deploy; uses Vault automatically if present' \
		'  make pull-data             Pull data; uses Vault automatically if present' \
		'  make stop                  Stop stack; uses Vault automatically if present' \
		'  make restart               Restart stack; uses Vault automatically if present' \
		'  make nuke CONFIRM_NUKE=true' \
		'                              Delete data; uses Vault automatically if present' \
		'' \
		'Variables:' \
		'  INVENTORY=path/to/inventory.yml' \
		'  PLAYBOOK=path/to/playbook.yml' \
		'  LIMIT=host-or-group' \
		'  CONFIRM_NUKE=true' \
		'  VAULT_FILE=group_vars/minecraft_servers/vault.yml'

setup: sync collections

sync:
	uv sync

collections:
	uv run ansible-galaxy collection install -r requirements.yml

lock-check:
	uv lock --check

lint:
	uv run yamllint .
	uv run ansible-playbook -i "$(EXAMPLE_INVENTORY)" --syntax-check "$(PLAYBOOK)"
	ANSIBLE_INVENTORY="$(EXAMPLE_INVENTORY)" uv run ansible-lint

check: lock-check lint

install-hooks:
	uv run pre-commit install

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

vault-create:
	@mkdir -p "$$(dirname "$(VAULT_FILE)")"
	@if [ -f "$(VAULT_FILE)" ]; then \
		printf '%s\n' "$(VAULT_FILE) already exists. Use make vault-edit instead."; \
	else \
		uv run ansible-vault create "$(VAULT_FILE)"; \
	fi

vault-edit:
	uv run ansible-vault edit "$(VAULT_FILE)"

vault-check:
	uv run ansible -i "$(INVENTORY)" "$(LIMIT)" -m ansible.builtin.debug -a 'msg={{ "configured" if ansible_become_password is defined and (ansible_become_password | length > 0) else "missing" }}' --ask-vault-pass

ping:
	uv run ansible -i "$(INVENTORY)" "$(LIMIT)" -m ping

deploy:
	uv run ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" $(VAULT_ARGS)

pull-data:
	uv run ansible-playbook -i "$(INVENTORY)" playbooks/pull-data.yml $(VAULT_ARGS)

stop:
	uv run ansible-playbook -i "$(INVENTORY)" playbooks/stop.yml $(VAULT_ARGS)

restart:
	uv run ansible-playbook -i "$(INVENTORY)" playbooks/restart.yml $(VAULT_ARGS)

nuke:
	uv run ansible-playbook -i "$(INVENTORY)" playbooks/nuke.yml -e "minecraft_confirm_nuke=$(CONFIRM_NUKE)" $(VAULT_ARGS)
