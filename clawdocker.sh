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

    # 4. Provider protocol
    local provider
    provider=$(prompt_choice "Provider protocol" "openai" "openai" "anthropic")

    # 5. Base URL
    local default_baseurl
    if [[ "$provider" == "openai" ]]; then
        default_baseurl="https://api.openai.com/v1"
    else
        default_baseurl="https://api.anthropic.com"
    fi
    local baseurl
    baseurl=$(prompt_input "API Base URL" "$default_baseurl")

    # 6. API Key
    local apikey
    apikey=$(prompt_input "API Key" "")

    # 7. Model
    local default_model
    if [[ "$provider" == "openai" ]]; then
        default_model="gpt-4o"
    else
        default_model="claude-sonnet-4-20250514"
    fi
    local model
    model=$(prompt_input "Model" "$default_model")

    # ─── Generate files ───────────────────────────────────────────────────────

    info "Creating instance at: $instance_path"
    mkdir -p "$instance_path/config/workspace"

    # --- docker-compose.yml ---
    cat > "$instance_path/docker-compose.yml" << EOF
services:
  openclaw-gateway:
    image: openclaw-gateway:latest
    container_name: openclaw-${name}
    restart: unless-stopped
    ports:
      - "${port}:18789"
    volumes:
      - ./config:/home/node/.openclaw:rw
      - ${name}_home:/home/node
    env_file:
      - .env

volumes:
  ${name}_home:
EOF

    # --- .env ---
    if [[ "$provider" == "openai" ]]; then
        cat > "$instance_path/.env" << EOF
OPENAI_API_KEY=${apikey}
OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 16 2>/dev/null || head -c 32 /dev/urandom | xxd -p | head -c 32)
EOF
    else
        cat > "$instance_path/.env" << EOF
ANTHROPIC_API_KEY=${apikey}
OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 16 2>/dev/null || head -c 32 /dev/urandom | xxd -p | head -c 32)
EOF
    fi

    # --- openclaw.json ---
    if [[ "$provider" == "openai" ]]; then
        cat > "$instance_path/config/openclaw.json" << EOF
{
  "agent": {
    "model": "openai-compatible:${model}",
    "providers": {
      "openai-compatible": {
        "baseUrl": "${baseurl}"
      }
    },
    "workspace": "~/.openclaw/workspace"
  },
  "gateway": {
    "host": "0.0.0.0",
    "port": 18789
  }
}
EOF
    else
        cat > "$instance_path/config/openclaw.json" << EOF
{
  "agent": {
    "model": "anthropic:${model}",
    "providers": {
      "anthropic": {
        "baseUrl": "${baseurl}"
      }
    },
    "workspace": "~/.openclaw/workspace"
  },
  "gateway": {
    "host": "0.0.0.0",
    "port": 18789
  }
}
EOF
    fi

    # --- Workspace files ---
    cat > "$instance_path/config/workspace/AGENTS.md" << 'EOF'
## Rules

- Confirm before executing destructive commands
- Reply in the user's language
- Keep responses concise and actionable

## Priority

1. Safety > Efficiency > Convenience
2. Prefer existing tools over installing new dependencies
EOF

    cat > "$instance_path/config/workspace/SOUL.md" << 'EOF'
## Personality

You are an efficient and professional assistant. Be concise, direct, and helpful.

## Boundaries

- Do not execute destructive operations without explicit confirmation
- Do not access or transmit sensitive data
- Ask for clarification when uncertain
EOF

    # --- instance.conf (metadata) ---
    cat > "$instance_path/instance.conf" << EOF
NAME=${name}
PORT=${port}
PROVIDER=${provider}
BASE_URL=${baseurl}
MODEL=${model}
CREATED=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
EOF

    # Register instance
    register_instance "$name" "$instance_path"

    echo ""
    info "Instance '${name}' created successfully!"
    echo ""
    echo "  Path:     $instance_path"
    echo "  Port:     $port"
    echo "  Provider: $provider"
    echo "  Model:    $model"
    echo ""
    echo "  Start with:  $(color_cyan "$0 start $instance_path")"
    echo "         or:   $(color_cyan "$0 start $name")"
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

    info "Starting instance at: $instance_path (project: $project)"
    cd "$instance_path" && docker compose -p "$project" up -d
    info "Instance started. Gateway port: $(grep -oP '"\K\d+(?=:18789")' "$instance_path/docker-compose.yml" 2>/dev/null || echo 'unknown')"
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
    printf "$(color_cyan '%-20s %-50s %-8s %-12s %s')\n" "NAME" "PATH" "PORT" "PROVIDER" "MODEL"
    echo "────────────────────────────────────────────────────────────────────────────────────────────────────"

    while IFS='|' read -r inst_name inst_path; do
        local port="?" provider="?" model="?"
        if [[ -f "$inst_path/instance.conf" ]]; then
            port=$(grep '^PORT=' "$inst_path/instance.conf" 2>/dev/null | cut -d= -f2 || echo "?")
            provider=$(grep '^PROVIDER=' "$inst_path/instance.conf" 2>/dev/null | cut -d= -f2 || echo "?")
            model=$(grep '^MODEL=' "$inst_path/instance.conf" 2>/dev/null | cut -d= -f2 || echo "?")
        fi
        printf "%-20s %-50s %-8s %-12s %s\n" "$inst_name" "$inst_path" "$port" "$provider" "$model"
    done < "$INSTANCES_REGISTRY"
    echo ""
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
    help|--help|-h) cmd_help ;;
    *)
        error "Unknown command: $command"
        cmd_help
        exit 1
        ;;
esac
