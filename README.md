# clawdocker

OpenClaw Docker instance manager. Build images, create/manage multiple OpenClaw instances with one command.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/tiltwind/clawdocker/main/install.sh | bash
```

Or specify a custom install directory:

```bash
CLAWDOCKER_HOME=/path/to/dir curl -fsSL https://raw.githubusercontent.com/tiltwind/clawdocker/main/install.sh | bash
```

## Usage

```
clawdocker <command> [options]
```

### Commands

| Command | Description |
|---|---|
| `clawdocker buildimage [--skip-clone]` | Clone/update OpenClaw repo and build Docker image |
| `clawdocker create` | Create a new instance interactively |
| `clawdocker start <name>` | Start an instance |
| `clawdocker stop <name>` | Stop an instance |
| `clawdocker restart <name>` | Restart an instance |
| `clawdocker status <name>` | Show instance status |
| `clawdocker logs <name>` | Tail instance logs |
| `clawdocker list` | List all registered instances |
| `clawdocker exec <name> <cmd...>` | Execute a command inside the container |
| `clawdocker remove <name>` | Remove an instance (stop, delete, unregister) |
| `clawdocker uninstall` | Uninstall OpenClaw (systemd, CLI, config) |
| `clawdocker help` | Show help |

### Quick start

```bash
# 1. Build the Docker image
clawdocker buildimage

# 2. Create an instance
clawdocker create

# 3. Start the instance
clawdocker start mybot

# 4. Configure OpenClaw
clawdocker exec mybot openclaw onboard
```

### Build image environment variables

| Variable | Default | Description |
|---|---|---|
| `OPENCLAW_REPO_URL` | `https://github.com/openclaw/openclaw.git` | Git repo URL |
| `OPENCLAW_REPO_DIR` | `/opt/openclaw` | Local repo path |
| `OPENCLAW_BRANCH` | *(latest release tag)* | Git branch/tag to build |
| `OPENCLAW_EXTENSIONS` | `acpx bluebubbles ...` | Extensions to include |
| `OPENCLAW_DOCKER_APT_PACKAGES` | `ffmpeg build-essential git curl jq` | Extra apt packages |
| `OPENCLAW_IMAGE` | `openclaw:local` | Docker image name |

## Update

Re-run the install command to update:

```bash
curl -fsSL https://raw.githubusercontent.com/tiltwind/clawdocker/main/install.sh | bash
```

## Uninstall clawdocker

```bash
sudo rm /usr/local/bin/clawdocker
rm -rf ~/.clawdocker
```
