#!/bin/bash
# despawn-user.sh — Remove a development user and their home directory
# Usage: sudo ./scripts/despawn-user.sh <username> [--yes]

set -euo pipefail

# --- Configuration ---
RESERVED_USERS="root cdelalama nobody daemon sys bin"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- Logging ---
log_done()    { echo -e "  ${GREEN}[DONE]${NC}    $1"; }
log_skipped() { echo -e "  ${BLUE}[SKIPPED]${NC}  $1"; }
log_error()   { echo -e "  ${RED}[ERROR]${NC}   $1" >&2; }

# --- Parse arguments ---

USERNAME=""
AUTO_YES=false

parse_args() {
    if [ $# -lt 1 ]; then
        echo "Usage: sudo $0 <username> [--yes]"
        exit 1
    fi

    USERNAME="$1"
    shift

    while [ $# -gt 0 ]; do
        case "$1" in
            --yes)
                AUTO_YES=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

# --- Validation ---

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

validate_username() {
    local username="$1"

    if ! echo "$username" | grep -qE '^[a-z_][a-z0-9_-]{0,31}$'; then
        log_error "Invalid username '$username'. Must match: ^[a-z_][a-z0-9_-]{0,31}$"
        exit 1
    fi

    for reserved in $RESERVED_USERS; do
        if [ "$username" = "$reserved" ]; then
            log_error "Username '$username' is protected and cannot be removed."
            exit 1
        fi
    done
}

# --- Main ---

main() {
    parse_args "$@"

    echo -e "${RED}dev-spawner${NC} — removing user '${USERNAME}'"
    echo ""

    check_root
    validate_username "$USERNAME"

    # Check user exists
    if ! id "$USERNAME" >/dev/null 2>&1; then
        echo -e "  User '$USERNAME' does not exist. Nothing to do."
        exit 0
    fi

    # Confirmation
    if [ "$AUTO_YES" != "true" ]; then
        echo -e "  ${RED}WARNING: This will permanently delete user '$USERNAME' and ALL their files.${NC}"
        echo -e "  Home directory: /home/$USERNAME"
        echo ""
        read -rp "  Are you sure? [y/N] " confirm
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            echo "  Aborted."
            exit 0
        fi
        echo ""
    fi

    # Kill user processes
    echo -e "${BLUE}--- Stopping user processes ---${NC}"
    if pgrep -u "$USERNAME" >/dev/null 2>&1; then
        pkill -u "$USERNAME" 2>/dev/null || true
        sleep 2

        # Check if processes remain, force kill if needed
        if pgrep -u "$USERNAME" >/dev/null 2>&1; then
            pkill -9 -u "$USERNAME" 2>/dev/null || true
            sleep 1

            if pgrep -u "$USERNAME" >/dev/null 2>&1; then
                log_error "Could not kill all processes for '$USERNAME'. Try manually."
                exit 1
            fi
        fi
        log_done "Stopped all processes for '$USERNAME'"
    else
        log_skipped "No running processes for '$USERNAME'"
    fi

    # Remove from docker group
    echo -e "${BLUE}--- Docker group ---${NC}"
    if id -nG "$USERNAME" 2>/dev/null | grep -qw docker; then
        gpasswd -d "$USERNAME" docker >/dev/null 2>&1 || true
        log_done "Removed '$USERNAME' from docker group"
    else
        log_skipped "'$USERNAME' not in docker group"
    fi

    # Delete user and home
    echo -e "${BLUE}--- Delete user ---${NC}"
    userdel -r "$USERNAME" 2>/dev/null
    log_done "Deleted user '$USERNAME' and /home/$USERNAME"

    # Summary
    echo ""
    echo -e "${GREEN}=============================${NC}"
    echo -e "${GREEN}  despawn-user.sh complete${NC}"
    echo -e "${GREEN}=============================${NC}"
    echo ""
    echo -e "  User '${USERNAME}' has been completely removed."
    echo ""
}

main "$@"
