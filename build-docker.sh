#!/bin/bash
set -euo pipefail

# build-docker.sh - Clone OpenClaw repo and build Docker image with extensions
#
# Usage:
#   ./build-docker.sh                    # Clone/update and build
#   ./build-docker.sh --skip-clone       # Skip clone, just rebuild
#   OPENCLAW_REPO_DIR=/path ./build-docker.sh  # Use custom repo path

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Configuration ──────────────────────────────────────────────────────────

# OpenClaw repo
OPENCLAW_REPO_URL="${OPENCLAW_REPO_URL:-https://github.com/openclaw/openclaw.git}"
OPENCLAW_REPO_DIR="${OPENCLAW_REPO_DIR:-/opt/openclaw}"
OPENCLAW_BRANCH="${OPENCLAW_BRANCH:-main}"

# Extensions to include (space-separated)
export OPENCLAW_EXTENSIONS="${OPENCLAW_EXTENSIONS:-nostr}"

# Extra apt packages to install in the image
export OPENCLAW_DOCKER_APT_PACKAGES="${OPENCLAW_DOCKER_APT_PACKAGES:-ffmpeg build-essential git curl jq}"

# Gateway defaults
export OPENCLAW_GATEWAY_BIND="${OPENCLAW_GATEWAY_BIND:-lan}"

# Image name
export OPENCLAW_IMAGE="${OPENCLAW_IMAGE:-openclaw:local}"

# ─── Helpers ────────────────────────────────────────────────────────────────

color_green()  { printf '\033[0;32m%s\033[0m' "$*"; }
color_cyan()   { printf '\033[0;36m%s\033[0m' "$*"; }
color_red()    { printf '\033[0;31m%s\033[0m' "$*"; }

info()  { echo "$(color_green '[INFO]')  $*"; }
error() { echo "$(color_red '[ERROR]') $*" >&2; }

# ─── Parse args ─────────────────────────────────────────────────────────────

SKIP_CLONE=false
for arg in "$@"; do
    case "$arg" in
        --skip-clone) SKIP_CLONE=true ;;
        --help|-h)
            echo "Usage: $0 [--skip-clone]"
            echo ""
            echo "Environment variables:"
            echo "  OPENCLAW_REPO_URL          Git repo URL (default: github.com/openclaw/openclaw)"
            echo "  OPENCLAW_REPO_DIR          Local repo path (default: /opt/openclaw)"
            echo "  OPENCLAW_BRANCH            Git branch (default: main)"
            echo "  OPENCLAW_EXTENSIONS        Extensions to include (default: nostr)"
            echo "  OPENCLAW_DOCKER_APT_PACKAGES  Extra apt packages (default: ffmpeg build-essential git curl jq)"
            echo "  OPENCLAW_GATEWAY_BIND      Gateway bind mode (default: lan)"
            echo "  OPENCLAW_IMAGE             Docker image name (default: openclaw:local)"
            exit 0
            ;;
        *)
            error "Unknown argument: $arg"
            exit 1
            ;;
    esac
done

# ─── Pre-checks ─────────────────────────────────────────────────────────────

if ! command -v docker &>/dev/null; then
    error "Docker is not installed. Please install Docker first."
    exit 1
fi

if ! docker compose version &>/dev/null; then
    error "Docker Compose plugin is not available."
    exit 1
fi

if ! command -v git &>/dev/null; then
    error "Git is not installed."
    exit 1
fi

# ─── Clone / Update repo ────────────────────────────────────────────────────

if [[ "$SKIP_CLONE" == false ]]; then
    if [[ -d "$OPENCLAW_REPO_DIR/.git" ]]; then
        info "Updating existing repo at: $OPENCLAW_REPO_DIR"
        cd "$OPENCLAW_REPO_DIR"
        git fetch origin
        git checkout "$OPENCLAW_BRANCH"
        git pull origin "$OPENCLAW_BRANCH"
    else
        info "Cloning OpenClaw to: $OPENCLAW_REPO_DIR"
        mkdir -p "$(dirname "$OPENCLAW_REPO_DIR")"
        git clone --branch "$OPENCLAW_BRANCH" "$OPENCLAW_REPO_URL" "$OPENCLAW_REPO_DIR"
    fi
else
    info "Skipping clone (--skip-clone)"
fi

if [[ ! -f "$OPENCLAW_REPO_DIR/docker-setup.sh" ]]; then
    error "docker-setup.sh not found at: $OPENCLAW_REPO_DIR"
    error "Is OPENCLAW_REPO_DIR set correctly?"
    exit 1
fi

# ─── Build ───────────────────────────────────────────────────────────────────

cd "$OPENCLAW_REPO_DIR"

echo ""
info "Build configuration:"
echo "  Repo:        $OPENCLAW_REPO_DIR"
echo "  Image:       $OPENCLAW_IMAGE"
echo "  Extensions:  $OPENCLAW_EXTENSIONS"
echo "  Apt packages: $OPENCLAW_DOCKER_APT_PACKAGES"
echo "  Gateway bind: $OPENCLAW_GATEWAY_BIND"
echo ""

info "Running docker-setup.sh ..."
exec ./docker-setup.sh
