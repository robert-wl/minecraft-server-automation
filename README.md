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
- `playbooks/group_vars/all.yml` - default Minecraft and Docker variables.
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
  `minecraft_memory`, `minecraft_motd`, `minecraft_ops`,
  `minecraft_container_name`, mod mode, and whitelist values.

### Sudo Password With Ansible Vault

If SSH key auth works but the remote sudo user still requires a password, store
the sudo password in an encrypted Ansible Vault group variable:

```bash
make vault-create
```

When the editor opens, add:

```yaml
ansible_become_password: "your-remote-sudo-password"
```

Save and close the editor. Ansible will create
`group_vars/minecraft_servers/vault.yml`, encrypted with the Vault password you
entered. This repo ignores that local vault file by default so deployment
secrets are not accidentally published.

Deploy with:

```bash
make deploy
```

When `group_vars/minecraft_servers/vault.yml` exists, `make deploy`
automatically prompts for the Vault password, decrypts
`ansible_become_password` in memory, and uses it for sudo. It does not prompt
for the SSH password.

You can also run the explicit Vault target:

```bash
make deploy-vault
```

To edit the encrypted sudo password later:

```bash
make vault-edit
```

To verify Ansible can read the sudo password variable without printing the
secret:

```bash
make vault-check
```

For fully non-interactive local runs, create a local Vault password file and
pass it to Ansible:

```bash
uv run ansible-playbook -i inventory.yml playbooks/minecraft.yml \
  --vault-password-file .vault-pass
```

Local Vault password files such as `.vault-pass` and local encrypted sudo
password files such as `group_vars/minecraft_servers/vault.yml` are ignored by
git.

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

The Docker container name defaults to the `minecraft_dir` directory name. For
example, `/opt/docker/minecraft-vanilla` creates a container named
`minecraft-vanilla`, and `/opt/docker/minecraft-fabric` creates
`minecraft-fabric`. Override it only when you need a different fixed name:

```yaml
minecraft_container_name: minecraft-production
```

Older inventories that set `minecraft_name` still use that value as the
container name, but new inventories should use `minecraft_container_name`.

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
