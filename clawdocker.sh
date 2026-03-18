#!/bin/bash
set -euo pipefail

# clawdocker - OpenClaw Docker instance manager
# Usage:
#   clawdocker.sh create              - Interactive create a new instance
#   clawdocker.sh start  [path]       - Start instance at path
#   clawdocker.sh stop   [path]       - Stop instance at path
#   clawdocker.sh restart [path]      - Restart instance at path
#   clawdocker.sh status [path]       - Show instance status
#   clawdocker.sh logs   [path]       - Tail instance logs
#   clawdocker.sh list                - List all instances
#   clawdocker.sh remove <path|name>  - Remove an instance (stop, delete, unregister)
#   clawdocker.sh exec   <path|name> <command...> - Execute a command inside the container
#   clawdocker.sh buildimage [--skip-clone]      - Clone/update OpenClaw repo and build Docker image
#   clawdocker.sh uninstall                       - Uninstall OpenClaw (systemd, CLI, config)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTANCES_REGISTRY="${SCRIPT_DIR}/.instances"

# ─── Helpers ──────────────────────────────────────────────────────────────────

color_green()  { printf '\033[0;32m%s\033[0m' "$*"; }
color_yellow() { printf '\033[0;33m%s\033[0m' "$*"; }
color_red()    { printf '\033[0;31m%s\033[0m' "$*"; }
color_cyan()   { printf '\033[0;36m%s\033[0m' "$*"; }

info()  { echo "$(color_green '[INFO]')  $*"; }
warn()  { echo "$(color_yellow '[WARN]')  $*"; }
error() { echo "$(color_red '[ERROR]') $*" >&2; }

prompt_input() {
    local prompt="$1" default="${2:-}" value
    if [[ -n "$default" ]]; then
        read -rp "$(color_cyan "$prompt") [$(color_yellow "$default")]: " value
        echo "${value:-$default}"
    else
        while true; do
            read -rp "$(color_cyan "$prompt"): " value
            if [[ -n "$value" ]]; then
                echo "$value"
                return
            fi
            warn "This field is required."
        done
    fi
}

prompt_choice() {
    local prompt="$1" default="$2"
    shift 2
    local options=("$@")
    echo "$(color_cyan "$prompt")" >&2
    for i in "${!options[@]}"; do
        local marker=" "
        if [[ "${options[$i]}" == "$default" ]]; then
            marker="*"
        fi
        echo "  $marker $((i+1))) ${options[$i]}" >&2
    done
    local choice
    read -rp "$(color_cyan 'Choose') [$(color_yellow "$default")]: " choice
    if [[ -z "$choice" ]]; then
        echo "$default"
        return
    fi
    # If numeric, map to option
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
        echo "${options[$((choice-1))]}"
    else
        echo "$choice"
    fi
}

register_instance() {
    local name="$1" path="$2"
    mkdir -p "$(dirname "$INSTANCES_REGISTRY")"
    # Remove existing entry with same name or path
    if [[ -f "$INSTANCES_REGISTRY" ]]; then
        grep -v "^${name}|" "$INSTANCES_REGISTRY" 2>/dev/null > "${INSTANCES_REGISTRY}.tmp" || true
        mv "${INSTANCES_REGISTRY}.tmp" "$INSTANCES_REGISTRY"
    fi
    echo "${name}|${path}" >> "$INSTANCES_REGISTRY"
}

get_compose_project() {
    local instance_path="$1"
    local name
    name=$(basename "$instance_path")
    echo "openclaw-${name}"
}

resolve_instance_path() {
    local input="$1"
    # If it's an absolute path, use directly
    if [[ "$input" == /* ]]; then
        echo "$input"
        return
    fi
    # If it matches a registered instance name, look it up
    if [[ -f "$INSTANCES_REGISTRY" ]]; then
        local match
        match=$(grep "^${input}|" "$INSTANCES_REGISTRY" 2>/dev/null | head -1 | cut -d'|' -f2)
        if [[ -n "$match" ]]; then
            echo "$match"
            return
        fi
    fi
    # Treat as relative path
    echo "$(pwd)/$input"
}

# ─── Commands ─────────────────────────────────────────────────────────────────

cmd_create() {
    echo ""
    echo "$(color_green '╔══════════════════════════════════════════╗')"
    echo "$(color_green '║')   OpenClaw Docker Instance Creator      $(color_green '║')"
    echo "$(color_green '╚══════════════════════════════════════════╝')"
    echo ""

    # 1. Name
    local name
    name=$(prompt_input "Instance name" "")

    # 2. Path
    local default_path="${PWD}/${name}"
    local instance_path
    instance_path=$(prompt_input "Instance path" "$default_path")

    # Expand ~ to HOME
    instance_path="${instance_path/#\~/$HOME}"

    if [[ -d "$instance_path" ]] && [[ -f "$instance_path/docker-compose.yml" ]]; then
        warn "Instance already exists at: $instance_path"
        local overwrite
        read -rp "$(color_yellow 'Overwrite? (y/N): ')" overwrite
        if [[ "$overwrite" != "y" && "$overwrite" != "Y" ]]; then
            info "Aborted."
            exit 0
        fi
    fi

    # 3. Port
    local port
    port=$(prompt_input "Host port" "18789")

    # Check port conflict against registered instances
    if [[ -f "$INSTANCES_REGISTRY" ]]; then
        while IFS='|' read -r reg_name reg_path; do
            if [[ -f "$reg_path/instance.conf" ]]; then
                local reg_port
                reg_port=$(grep '^PORT=' "$reg_path/instance.conf" 2>/dev/null | cut -d= -f2)
                if [[ "$reg_port" == "$port" && "$reg_name" != "$name" ]]; then
                    error "Port ${port} is already used by instance '${reg_name}' (${reg_path})"
                    exit 1
                fi
            fi
        done < "$INSTANCES_REGISTRY"
    fi

    # Check port conflict against running processes
    if lsof -iTCP:"$port" -sTCP:LISTEN -t &>/dev/null; then
        error "Port ${port} is already in use by another process"
        exit 1
    fi

    # 4. Image selection
    local images=()
    while IFS= read -r img; do
        [[ -n "$img" ]] && images+=("$img")
    done < <(docker images --format '{{.Repository}}:{{.Tag}}' | grep -i 'openclaw:' | sort -V)

    local image
    if [[ ${#images[@]} -eq 0 ]]; then
        warn "No openclaw images found locally."
        image=$(prompt_input "Docker image" "openclaw:latest")
    elif [[ ${#images[@]} -eq 1 ]]; then
        info "Found image: ${images[0]}"
        image="${images[0]}"
    else
        image=$(prompt_choice "Select Docker image:" "${images[0]}" "${images[@]}")
    fi

    # ─── Generate files ───────────────────────────────────────────────────────

    info "Creating instance at: $instance_path"
    mkdir -p "$instance_path/config/workspace"
    mkdir -p "$instance_path/home"

    # --- docker-compose.yml ---
    cat > "$instance_path/docker-compose.yml" << EOF
services:
  openclaw-gateway:
    image: ${image}
    container_name: openclaw-${name}
    restart: unless-stopped
    ports:
      - "127.0.0.1:${port}:18789"
    volumes:
      - ./config:/home/node/.openclaw:rw
      - ./home:/home/node
    env_file:
      - .env
EOF

    # --- .env ---
    cat > "$instance_path/.env" << EOF
OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 16 2>/dev/null || head -c 32 /dev/urandom | xxd -p | head -c 32)
EOF

    # --- openclaw.json (minimal, configure via openclaw setup after start) ---
    cat > "$instance_path/config/openclaw.json" << 'EOF'
{
  "gateway": {
    "port": 18789
  }
}
EOF

    # Ensure container's node user (uid 1000) can read/write/create
    chown -R 1000:1000 "$instance_path/config" 2>/dev/null || true
    chmod -R 700 "$instance_path/config"
    chown -R 1000:1000 "$instance_path/home" 2>/dev/null || true
    chmod -R 700 "$instance_path/home"

    # --- instance.conf (metadata) ---
    cat > "$instance_path/instance.conf" << EOF
NAME=${name}
PORT=${port}
IMAGE=${image}
CREATED=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
EOF

    # Register instance
    register_instance "$name" "$instance_path"

    echo ""
    info "Instance '${name}' created successfully!"
    echo ""
    echo "  Path:  $instance_path"
    echo "  Port:  $port"
    echo "  Image: $image"
    echo ""
    echo "  Next steps:"
    echo "    1. Start:     $(color_cyan "$0 start $name")"
    echo "    2. Configure: $(color_cyan "$0 exec $name openclaw onboard")"
    echo ""
}

cmd_start() {
    local input="${1:-}"
    if [[ -z "$input" ]]; then
        error "Usage: $0 start <path|name>"
        exit 1
    fi

    local instance_path
    instance_path=$(resolve_instance_path "$input")

    if [[ ! -f "$instance_path/docker-compose.yml" ]]; then
        error "No docker-compose.yml found at: $instance_path"
        error "Run '$0 create' first to create an instance."
        exit 1
    fi

    local project
    project=$(get_compose_project "$instance_path")

    # Check port conflict before starting
    local port
    port=$(grep -oP '"\K\d+(?=:18789")' "$instance_path/docker-compose.yml" 2>/dev/null || echo "")
    if [[ -n "$port" ]] && lsof -iTCP:"$port" -sTCP:LISTEN -t &>/dev/null; then
        error "Port ${port} is already in use. Cannot start instance."
        error "Stop the conflicting process or change the port in: $instance_path/docker-compose.yml"
        exit 1
    fi

    info "Starting instance at: $instance_path (project: $project)"
    if ! cd "$instance_path" || ! docker compose -p "$project" up -d; then
        error "Failed to start instance. Cleaning up containers..."
        docker compose -p "$project" down 2>/dev/null || true
        exit 1
    fi
    info "Instance started. Gateway port: ${port:-unknown}"
}

cmd_stop() {
    local input="${1:-}"
    if [[ -z "$input" ]]; then
        error "Usage: $0 stop <path|name>"
        exit 1
    fi

    local instance_path
    instance_path=$(resolve_instance_path "$input")

    if [[ ! -f "$instance_path/docker-compose.yml" ]]; then
        error "No docker-compose.yml found at: $instance_path"
        exit 1
    fi

    local project
    project=$(get_compose_project "$instance_path")

    info "Stopping instance: $project"
    cd "$instance_path" && docker compose -p "$project" stop
}

cmd_restart() {
    local input="${1:-}"
    if [[ -z "$input" ]]; then
        error "Usage: $0 restart <path|name>"
        exit 1
    fi

    local instance_path
    instance_path=$(resolve_instance_path "$input")

    if [[ ! -f "$instance_path/docker-compose.yml" ]]; then
        error "No docker-compose.yml found at: $instance_path"
        exit 1
    fi

    local project
    project=$(get_compose_project "$instance_path")

    info "Restarting instance: $project"
    cd "$instance_path" && docker compose -p "$project" restart
}

cmd_status() {
    local input="${1:-}"
    if [[ -z "$input" ]]; then
        error "Usage: $0 status <path|name>"
        exit 1
    fi

    local instance_path
    instance_path=$(resolve_instance_path "$input")

    if [[ ! -f "$instance_path/docker-compose.yml" ]]; then
        error "No docker-compose.yml found at: $instance_path"
        exit 1
    fi

    local project
    project=$(get_compose_project "$instance_path")

    cd "$instance_path" && docker compose -p "$project" ps
}

cmd_logs() {
    local input="${1:-}"
    if [[ -z "$input" ]]; then
        error "Usage: $0 logs <path|name>"
        exit 1
    fi

    local instance_path
    instance_path=$(resolve_instance_path "$input")

    if [[ ! -f "$instance_path/docker-compose.yml" ]]; then
        error "No docker-compose.yml found at: $instance_path"
        exit 1
    fi

    local project
    project=$(get_compose_project "$instance_path")

    cd "$instance_path" && docker compose -p "$project" logs -f
}

cmd_list() {
    if [[ ! -f "$INSTANCES_REGISTRY" ]] || [[ ! -s "$INSTANCES_REGISTRY" ]]; then
        info "No registered instances."
        return
    fi

    echo ""
    printf "$(color_cyan '%-20s %-50s %-8s')\n" "NAME" "PATH" "PORT"
    echo "──────────────────────────────────────────────────────────────────────────────────"

    while IFS='|' read -r inst_name inst_path; do
        local port="?"
        if [[ -f "$inst_path/instance.conf" ]]; then
            port=$(grep '^PORT=' "$inst_path/instance.conf" 2>/dev/null | cut -d= -f2 || echo "?")
        fi
        printf "%-20s %-50s %-8s\n" "$inst_name" "$inst_path" "$port"
    done < "$INSTANCES_REGISTRY"
    echo ""
}

cmd_exec() {
    local input="${1:-}"
    if [[ -z "$input" ]]; then
        error "Usage: $0 exec <path|name> <command...>"
        echo ""
        echo "  Execute a command inside the Docker container."
        echo ""
        echo "  Examples:"
        echo "    $0 exec mybot openclaw channels set feishu"
        echo "    $0 exec mybot openclaw channels status --probe"
        echo "    $0 exec mybot openclaw devices list"
        echo "    $0 exec mybot sh"
        echo ""
        exit 1
    fi

    local instance_path
    instance_path=$(resolve_instance_path "$input")
    shift  # consume the instance path/name, remaining args are the command

    if [[ $# -eq 0 ]]; then
        error "No command specified."
        error "Usage: $0 exec <path|name> <command...>"
        exit 1
    fi

    if [[ ! -f "$instance_path/docker-compose.yml" ]]; then
        error "No docker-compose.yml found at: $instance_path"
        error "Run '$0 create' first."
        exit 1
    fi

    local project
    project=$(get_compose_project "$instance_path")
    local container_name="openclaw-$(basename "$instance_path")"

    # Check that the container is running
    if ! docker compose -p "$project" ps --status running 2>/dev/null | grep -q "openclaw"; then
        error "Instance is not running. Start it first with: $0 start $(basename "$instance_path")"
        exit 1
    fi

    docker exec -it "$container_name" "$@"
}

cmd_remove() {
    local input="${1:-}"
    if [[ -z "$input" ]]; then
        error "Usage: $0 remove <path|name>"
        exit 1
    fi

    local instance_path
    instance_path=$(resolve_instance_path "$input")
    local name
    name=$(basename "$instance_path")

    if [[ ! -d "$instance_path" ]]; then
        error "Instance directory not found: $instance_path"
        exit 1
    fi

    # Confirm with user
    warn "This will stop and remove instance '${name}' at: $instance_path"
    warn "  - Stop and remove containers and networks"
    warn "  - Delete instance directory: $instance_path"
    local confirm
    read -rp "$(color_red 'Are you sure? (y/N): ')" confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        info "Aborted."
        exit 0
    fi

    # Stop and remove containers, networks, volumes
    local project
    project=$(get_compose_project "$instance_path")
    if [[ -f "$instance_path/docker-compose.yml" ]]; then
        info "Stopping and removing containers..."
        cd "$instance_path" && docker compose -p "$project" down -v 2>/dev/null || true
    fi

    # Remove instance directory
    info "Removing instance directory: $instance_path"
    rm -rf "$instance_path"

    # Unregister from instances registry
    if [[ -f "$INSTANCES_REGISTRY" ]]; then
        grep -v "|${instance_path}$" "$INSTANCES_REGISTRY" > "${INSTANCES_REGISTRY}.tmp" 2>/dev/null || true
        mv "${INSTANCES_REGISTRY}.tmp" "$INSTANCES_REGISTRY"
    fi

    info "Instance '${name}' removed."
}

cmd_uninstall() {
    echo ""
    echo "$(color_red '╔══════════════════════════════════════════╗')"
    echo "$(color_red '║')   OpenClaw Uninstaller                    $(color_red '║')"
    echo "$(color_red '╚══════════════════════════════════════════╝')"
    echo ""
    warn "This will perform the following actions:"
    echo "  1. Stop and remove systemd service (openclaw-gateway)"
    echo "  2. Uninstall OpenClaw CLI (npm uninstall -g openclaw)"
    echo "  3. Remove config files (~/.openclaw, ~/.config/openclaw)"
    echo ""

    local confirm
    read -rp "$(color_red 'Are you sure you want to uninstall OpenClaw? (y/N): ')" confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        info "Aborted."
        return 0
    fi

    # Second confirmation
    read -rp "$(color_red 'This action is irreversible. Type "UNINSTALL" to confirm: ')" confirm
    if [[ "$confirm" != "UNINSTALL" ]]; then
        info "Aborted."
        return 0
    fi

    echo ""

    # STEP 1. Stop and remove systemd service
    info "[1/4] Stopping and removing systemd service..."
    if systemctl --user stop openclaw-gateway 2>/dev/null; then
        echo "  Stopped openclaw-gateway"
    else
        echo "  Service not running, skipped"
    fi
    if systemctl --user disable openclaw-gateway 2>/dev/null; then
        echo "  Disabled auto-start"
    else
        echo "  Service not enabled, skipped"
    fi
    rm -f ~/.config/systemd/user/openclaw-gateway.service
    systemctl --user daemon-reload 2>/dev/null || true
    echo "  systemd config reloaded"

    # STEP 2. Uninstall OpenClaw CLI
    info "[2/4] Uninstalling OpenClaw CLI..."
    if command -v openclaw &>/dev/null; then
        npm uninstall -g openclaw
        echo "  openclaw uninstalled"
    else
        echo "  openclaw not installed, skipped"
    fi

    # STEP 3. Clean up config files
    info "[3/4] Cleaning up config files..."
    rm -rf ~/.openclaw
    rm -rf ~/.config/openclaw
    echo "  Config files removed"

    # STEP 4. Verify
    info "[4/4] Verifying uninstall..."
    hash -r 2>/dev/null
    if which openclaw 2>/dev/null | grep -q openclaw; then
        warn "openclaw command still exists: $(which openclaw)"
    else
        echo "  openclaw command removed"
    fi

    if systemctl --user list-unit-files openclaw-gateway.service 2>/dev/null | grep -q openclaw-gateway; then
        warn "openclaw-gateway service still exists"
    else
        echo "  openclaw-gateway service removed"
    fi

    echo ""
    info "Uninstall complete."
    echo "To also uninstall Node.js, run: sudo apt remove -y nodejs && sudo apt autoremove -y"
}

cmd_build_image() {
    # ─── Configuration ──────────────────────────────────────────────────────
    OPENCLAW_REPO_URL="${OPENCLAW_REPO_URL:-https://github.com/openclaw/openclaw.git}"
    OPENCLAW_REPO_DIR="${OPENCLAW_REPO_DIR:-/opt/openclaw}"
    OPENCLAW_BRANCH="${OPENCLAW_BRANCH:-}"  # empty = auto-detect latest release tag

    # Extensions to include (space-separated)
    export OPENCLAW_EXTENSIONS="${OPENCLAW_EXTENSIONS:-acpx bluebubbles diagnostics-otel feishu irc lobster matrix mattermost msteams nextcloud-talk nostr synology-chat twitch voice-call zalo zalouser}"

    # Extra apt packages to install in the image
    export OPENCLAW_DOCKER_APT_PACKAGES="${OPENCLAW_DOCKER_APT_PACKAGES:-ffmpeg build-essential git curl jq}"

    # Image name
    export OPENCLAW_IMAGE="${OPENCLAW_IMAGE:-openclaw:local}"

    # ─── Parse args ─────────────────────────────────────────────────────────
    local SKIP_CLONE=false
    for arg in "$@"; do
        case "$arg" in
            --skip-clone) SKIP_CLONE=true ;;
            --help|-h)
                echo "Usage: $0 buildimage [--skip-clone]"
                echo ""
                echo "Environment variables:"
                echo "  OPENCLAW_REPO_URL          Git repo URL (default: github.com/openclaw/openclaw)"
                echo "  OPENCLAW_REPO_DIR          Local repo path (default: /opt/openclaw)"
                echo "  OPENCLAW_BRANCH            Git branch/tag (default: latest release tag)"
                echo "  OPENCLAW_EXTENSIONS        Extensions to include"
                echo "  OPENCLAW_DOCKER_APT_PACKAGES  Extra apt packages (default: ffmpeg build-essential git curl jq)"
                echo "  OPENCLAW_IMAGE             Docker image name (default: openclaw:local)"
                return 0
                ;;
            *)
                error "Unknown argument: $arg"
                return 1
                ;;
        esac
    done

    # ─── Pre-checks ─────────────────────────────────────────────────────────
    if ! command -v docker &>/dev/null; then
        error "Docker is not installed. Please install Docker first."
        return 1
    fi

    if ! command -v git &>/dev/null; then
        error "Git is not installed."
        return 1
    fi

    # ─── Clone / Update repo ────────────────────────────────────────────────
    if [[ "$SKIP_CLONE" == false ]]; then
        if [[ -d "$OPENCLAW_REPO_DIR/.git" ]]; then
            info "Updating existing repo at: $OPENCLAW_REPO_DIR"
            cd "$OPENCLAW_REPO_DIR"
            git fetch origin --tags
        else
            info "Cloning OpenClaw to: $OPENCLAW_REPO_DIR"
            mkdir -p "$(dirname "$OPENCLAW_REPO_DIR")"
            git clone "$OPENCLAW_REPO_URL" "$OPENCLAW_REPO_DIR"
            cd "$OPENCLAW_REPO_DIR"
        fi

        # Determine which ref to check out
        if [[ -n "$OPENCLAW_BRANCH" ]]; then
            info "Using specified ref: $OPENCLAW_BRANCH"
            git checkout "$OPENCLAW_BRANCH"
        else
            # Auto-detect latest stable release tag (exclude beta/rc/alpha/dev)
            local LATEST_TAG
            LATEST_TAG="$(git tag -l --sort=-version:refname | grep -v -iE '(alpha|beta|rc|dev|pre)' | head -n 1)"
            if [[ -z "$LATEST_TAG" ]]; then
                error "No release tags found. Falling back to main."
                OPENCLAW_BRANCH="main"
                git checkout main
            else
                OPENCLAW_BRANCH="$LATEST_TAG"
                info "Latest release tag: $LATEST_TAG"
                git checkout "$LATEST_TAG"
            fi
        fi
    else
        info "Skipping clone (--skip-clone)"
    fi

    if [[ ! -f "$OPENCLAW_REPO_DIR/Dockerfile" ]]; then
        error "Dockerfile not found at: $OPENCLAW_REPO_DIR"
        error "Is OPENCLAW_REPO_DIR set correctly?"
        return 1
    fi

    # ─── Build ──────────────────────────────────────────────────────────────
    cd "$OPENCLAW_REPO_DIR"

    echo ""
    info "Build configuration:"
    echo "  Repo:        $OPENCLAW_REPO_DIR"
    echo "  Version:     $OPENCLAW_BRANCH"
    echo "  Image:       $OPENCLAW_IMAGE"
    echo "  Extensions:  $OPENCLAW_EXTENSIONS"
    echo "  Apt packages: $OPENCLAW_DOCKER_APT_PACKAGES"
    echo ""

    local OPENCLAW_IMAGE_BASE="${OPENCLAW_IMAGE%%:*}"

    info "Building Docker image ..."
    docker build \
        --build-arg OPENCLAW_EXTENSIONS="$OPENCLAW_EXTENSIONS" \
        --build-arg OPENCLAW_DOCKER_APT_PACKAGES="$OPENCLAW_DOCKER_APT_PACKAGES" \
        -t "$OPENCLAW_IMAGE" \
        -f Dockerfile \
        .

    # Tag with version and latest
    local TAGS=("${OPENCLAW_IMAGE_BASE}:latest")
    if [[ "$OPENCLAW_BRANCH" =~ ^v?[0-9] ]]; then
        TAGS+=("${OPENCLAW_IMAGE_BASE}:${OPENCLAW_BRANCH}")
    fi

    for tag in "${TAGS[@]}"; do
        info "Tagging $OPENCLAW_IMAGE -> $tag"
        docker tag "$OPENCLAW_IMAGE" "$tag"
    done

    info "Done. Images available:"
    echo "  $OPENCLAW_IMAGE"
    for tag in "${TAGS[@]}"; do
        echo "  $tag"
    done
}

cmd_help() {
    echo ""
    echo "$(color_green 'clawdocker') - OpenClaw Docker Instance Manager"
    echo ""
    echo "Usage:"
    echo "  $0 $(color_cyan 'create')              Create a new instance interactively"
    echo "  $0 $(color_cyan 'start')   <path|name>  Start an instance"
    echo "  $0 $(color_cyan 'stop')    <path|name>  Stop an instance"
    echo "  $0 $(color_cyan 'restart') <path|name>  Restart an instance"
    echo "  $0 $(color_cyan 'status')  <path|name>  Show instance status"
    echo "  $0 $(color_cyan 'logs')    <path|name>  Tail instance logs"
    echo "  $0 $(color_cyan 'list')                 List all registered instances"
    echo "  $0 $(color_cyan 'remove')  <path|name>  Remove an instance (stop, delete files, unregister)"
    echo "  $0 $(color_cyan 'exec')    <path|name> <cmd...>  Execute a command inside the container"
    echo "  $0 $(color_cyan 'buildimage') [--skip-clone]   Clone/update OpenClaw repo and build Docker image"
    echo "  $0 $(color_cyan 'uninstall')                  Uninstall OpenClaw (systemd, CLI, config)"
    echo ""
}

# ─── Main ─────────────────────────────────────────────────────────────────────

command="${1:-help}"
shift || true

case "$command" in
    create)  cmd_create "$@" ;;
    start)   cmd_start "$@" ;;
    stop)    cmd_stop "$@" ;;
    restart) cmd_restart "$@" ;;
    status)  cmd_status "$@" ;;
    logs)    cmd_logs "$@" ;;
    list)    cmd_list "$@" ;;
    remove)  cmd_remove "$@" ;;
    exec)        cmd_exec "$@" ;;
    buildimage) cmd_build_image "$@" ;;
    uninstall)   cmd_uninstall "$@" ;;
    help|--help|-h) cmd_help ;;
    *)
        error "Unknown command: $command"
        cmd_help
        exit 1
        ;;
esac
