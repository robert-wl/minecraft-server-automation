# Minecraft Server Automation

Ansible automation for provisioning a Docker-based Minecraft server using
[`itzg/minecraft-server`](https://github.com/itzg/docker-minecraft-server).

The default target is an Ubuntu/Debian host. The playbook installs Docker,
deploys a Docker Compose project, opens the Minecraft port with UFW when UFW is
installed, and starts the server container.

## Files

- `ansible.cfg` - local Ansible defaults for this project.
- `inventory.example.yml` - copy this to `inventory.yml` and set your server.
- `Makefile` - convenience targets for setup, checks, and deploys.
- `playbooks/minecraft.yml` - provisions Docker and starts the server.
- `playbooks/stop.yml` - stops and removes the Minecraft Compose stack.
- `playbooks/restart.yml` - restarts the Minecraft Compose stack.
- `playbooks/nuke.yml` - stops Minecraft and deletes the server data directory.
- `templates/docker-compose.yml.j2` - Compose file for `itzg/minecraft-server`.
- `requirements.yml` - Ansible collection dependencies for Docker Compose and
  local data sync.

## Prerequisites

On your control machine:

```bash
uv sync
uv run ansible-galaxy collection install -r requirements.yml
```

Or with Make:

```bash
make setup
```

On the target server:

- SSH access with a sudo-capable user.
- Ubuntu or Debian.
- The configured Minecraft port reachable from players.

## CI / Local Checks

GitHub Actions checks that the lockfile is current, installs the Ansible
collections, lints YAML and Ansible content, and runs a playbook syntax check
against the example inventory.

Run the same checks locally with:

```bash
uv lock --check
uv sync --locked
uv run ansible-galaxy collection install -r requirements.yml
uv run yamllint .
uv run ansible-playbook -i inventory.example.yml --syntax-check playbooks/minecraft.yml
ANSIBLE_INVENTORY=inventory.example.yml uv run ansible-lint
```

## Configure

Create your inventory:

```bash
cp inventory.example.yml inventory.yml
```

Or:

```bash
make inventory
```

Edit `inventory.yml` and set:

- `ansible_host`
- `ansible_user`
- `minecraft_eula: "TRUE"` after you have read and accepted the Minecraft EULA.
- `minecraft_port`, if you do not want the default `25565`.
- Optional server settings such as `minecraft_type`, `minecraft_version`,
  `minecraft_memory`, `minecraft_motd`, `minecraft_ops`, and whitelist values.

To seed the server from Minecraft data on this local machine, set:

```yaml
minecraft_local_data_dir: ./minecraft-data
```

When this is set, the playbook stops the Minecraft container, syncs the local
directory into the remote server data directory, and starts the container again.
By default it does not delete remote files that are missing locally. Set
`minecraft_local_data_delete: true` if you want the remote data directory to
mirror the local one exactly.

## Deploy

```bash
uv run ansible-playbook playbooks/minecraft.yml
```

Or:

```bash
make deploy
```

The server data is stored on the host in `/opt/docker/minecraft-vanilla/data`
by default.

## Make Targets

Show available targets:

```bash
make help
```

Run a syntax check before deploying:

```bash
make syntax-check
```

Check SSH/Ansible connectivity:

```bash
make ping
```

Prompt for an SSH password instead of using an SSH key:

```bash
make ping-password
```

Deploy with SSH and sudo password prompts:

```bash
make deploy-password
```

Stop the Minecraft stack while keeping server data:

```bash
make stop
```

Restart the Minecraft stack:

```bash
make restart
```

Stop Minecraft and delete the server data directory:

```bash
make nuke CONFIRM_NUKE=true
```

Use the password variants when SSH or sudo requires a password:

```bash
make stop-password
make restart-password
make nuke-password CONFIRM_NUKE=true
```

Use a different inventory file:

```bash
make deploy INVENTORY=staging.yml
```

## Common Operations

View logs:

```bash
ssh <server> 'cd /opt/docker/minecraft-vanilla && sudo docker compose logs -f minecraft'
```

Restart the server:

```bash
make restart
```

Stop the server:

```bash
make stop
```

Back up the world directory before changing major server versions:

```bash
ssh <server> 'sudo tar -C /opt/docker/minecraft-vanilla/data -czf /opt/docker/minecraft-vanilla/world-backup.tgz world'
```
