# Minecraft Server Automation

Ansible automation for provisioning a Docker-based Minecraft server using
[`itzg/minecraft-server`](https://github.com/itzg/docker-minecraft-server).

The default target is an Ubuntu/Debian host. The playbook installs Docker,
deploys a Docker Compose project, opens the Minecraft port with UFW when UFW is
installed, and starts the server container.

## Files

- `ansible.cfg` - local Ansible defaults for this project.
- `inventory.example.yml` - copy this to `inventory.yml` and set your server.
- `playbooks/minecraft.yml` - provisions Docker and starts the server.
- `playbooks/templates/docker-compose.yml.j2` - Compose file for
  `itzg/minecraft-server`.
- `requirements.yml` - Ansible collection dependencies for Docker Compose and
  local data sync.

## Prerequisites

On your control machine:

```bash
uv sync
uv run ansible-galaxy collection install -r requirements.yml
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

The server data is stored on the host in `/opt/minecraft/data` by default.

## Common Operations

View logs:

```bash
ssh <server> 'cd /opt/minecraft && sudo docker compose logs -f minecraft'
```

Restart the server:

```bash
ssh <server> 'cd /opt/minecraft && sudo docker compose restart minecraft'
```

Stop the server:

```bash
ssh <server> 'cd /opt/minecraft && sudo docker compose down'
```

Back up the world directory before changing major server versions:

```bash
ssh <server> 'sudo tar -C /opt/minecraft/data -czf /opt/minecraft/world-backup.tgz world'
```
