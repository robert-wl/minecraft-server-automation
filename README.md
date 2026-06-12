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
- `playbooks/pull-data.yml` - snapshots remote data and pulls it locally.
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
make setup
make check
```

Install the pre-commit hooks once per clone to run the same local checks before
commits:

```bash
make install-hooks
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
  `minecraft_memory`, `minecraft_motd`, `minecraft_ops`, mod mode, and
  whitelist values.

### Server Type

Vanilla is the default server type:

```yaml
minecraft_type: VANILLA
```

To run Fabric, set:

```yaml
minecraft_type: FABRIC
minecraft_version: "1.21.6"
```

The `itzg/minecraft-server` image installs the latest compatible Fabric loader
and launcher by default. Pin them only when you need a specific version:

```yaml
minecraft_fabric_loader_version: "0.16.14"
minecraft_fabric_launcher_version: "1.0.3"
```

Advanced Fabric options are also available:

```yaml
minecraft_fabric_launcher: fabric-server-custom.jar
minecraft_fabric_meta_base_url: https://meta.fabricmc.net
```

Fabric mods can be seeded by placing them under `mods/` in
`minecraft_local_data_dir`, since that directory syncs into the container's
`/data` volume.

To seed the server from Minecraft data on this local machine, set:

```yaml
minecraft_local_data_dir: ./minecraft-data
```

When this is set, the playbook stops the Minecraft container, syncs the local
directory into the remote server data directory, and starts the container again.
By default it does not delete remote files that are missing locally. Set
`minecraft_local_data_delete: true` if you want the remote data directory to
mirror the local one exactly.

To pull the remote server data back to this machine, use:

```bash
make pull-data
```

The pull playbook briefly stops the remote Minecraft stack, copies live data to
a remote snapshot directory, starts the stack again, and then syncs that stable
snapshot down to `minecraft_local_data_dir`. The default snapshot path is a
sibling of the live data directory:

```yaml
minecraft_remote_snapshot_dir: "{{ minecraft_dir }}/sync-snapshot"
```

Do not place the snapshot under `minecraft_data_dir`; that would make the
snapshot part of the live `/data` tree. By default the remote snapshot is
deleted after a successful pull. Set `minecraft_pull_cleanup_snapshot: false`
to keep it on the server.

The final pull uses `rsync` from the local machine to the remote server. That
connection must work with key-based SSH, and `sudo rsync` on the remote host
must not require an interactive sudo password.

## Mods

Set `minecraft_type` to the needed server loader, such as `FABRIC` or `FORGE`,
then choose how mods are supplied with `minecraft_mod_mode`.

`none` is the default. It does not configure any itzg download automation; the
server uses whatever is already in `/data`, including files synced from
`minecraft-data/mods` when `minecraft_local_data_dir: ./minecraft-data` is set.

```yaml
minecraft_type: FABRIC
minecraft_mod_mode: none
minecraft_local_data_dir: ./minecraft-data
```

Use `urls` for direct jar URLs or container paths:

```yaml
minecraft_type: FABRIC
minecraft_mod_mode: urls
minecraft_mod_urls: |
  https://example.com/mods/example-mod.jar
```

Use `urls_file` for an itzg `MODS_FILE` text file. The value can be a URL or a
container path. For a repo-managed file, put `mods.txt` in `minecraft-data` and
set `minecraft_local_data_dir`, then reference `/data/mods.txt`.

```yaml
minecraft_type: FABRIC
minecraft_mod_mode: urls_file
minecraft_local_data_dir: ./minecraft-data
minecraft_mods_file: /data/mods.txt
```

Use `modrinth` for Modrinth project slugs or IDs:

```yaml
minecraft_type: FABRIC
minecraft_mod_mode: modrinth
minecraft_modrinth_projects: |
  fabric-api
  lithium
```

Use `curseforge` for CurseForge project/file references. This requires a
CurseForge API key or key file.

```yaml
minecraft_type: FORGE
minecraft_mod_mode: curseforge
minecraft_curseforge_files: |
  jei
minecraft_curseforge_api_key: "change-this-key"
```

## Deploy

```bash
uv run ansible-playbook playbooks/minecraft.yml
```

Or:

```bash
make deploy
```

The server data is stored on the host in `/opt/docker/minecraft-vanilla/data`
by default. If you change `minecraft_type` and do not set `minecraft_dir`, the
path changes with it, for example `/opt/docker/minecraft-fabric/data`.

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

Pull remote server data to `./minecraft-data`:

```bash
make pull-data
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
