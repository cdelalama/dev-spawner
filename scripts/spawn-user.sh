#!/bin/bash
# spawn-user.sh — Create or update a development user environment on dev-vm
# Usage: sudo ./scripts/spawn-user.sh <username> [options]
#
# Options:
#   --git-name "Name"           Git user.name (required on first run)
#   --git-email "email"         Git user.email (required on first run)
#   --with-ollama               Add OLLAMA_HOST env var (default: 127.0.0.1:11434)
#   --ollama-host "host:port"   Override OLLAMA_HOST (implies --with-ollama)
#   --with-sounds               Install Claude Code sound hooks
#   --copy-admin-credentials    Copy Claude API key from admin ($SUDO_USER)
#   --update-templates          Overwrite existing dotfiles (creates .bak backups)

set -euo pipefail

# --- Configuration ---
NVM_VERSION="v0.40.4"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATES_DIR="$REPO_DIR/templates"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
RESERVED_USERS="root cdelalama nobody daemon sys bin"
DEFAULT_OLLAMA_HOST="127.0.0.1:11434"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- Logging ---
log_created()  { echo -e "  ${GREEN}[CREATED]${NC}  $1"; }
log_skipped()  { echo -e "  ${BLUE}[SKIPPED]${NC}  $1"; }
log_updated()  { echo -e "  ${YELLOW}[UPDATED]${NC} $1"; }
log_warning()  { echo -e "  ${YELLOW}[WARNING]${NC} $1"; }
log_error()    { echo -e "  ${RED}[ERROR]${NC}   $1" >&2; }
log_section()  { echo -e "\n${BLUE}--- $1 ---${NC}"; }

# --- Counters ---
COUNT_CREATED=0
COUNT_SKIPPED=0
COUNT_UPDATED=0
COUNT_WARNINGS=0

# --- Helpers ---

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_prerequisites() {
    local missing=()
    local cmds=(bash curl git useradd usermod userdel gpasswd pkill pgrep ssh-keygen sed chown chmod)

    for cmd in "${cmds[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done

    # Check docker group exists
    if ! getent group docker >/dev/null 2>&1; then
        missing+=("docker-group")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing prerequisites: ${missing[*]}"
        log_error "Install them before running this script."
        exit 1
    fi
}

check_network() {
    if ! curl -sf --max-time 5 https://github.com >/dev/null 2>&1; then
        log_error "No internet connectivity (cannot reach github.com)"
        log_error "NVM, Node, and Claude Code installation require internet access."
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
            log_error "Username '$username' is reserved and cannot be used."
            exit 1
        fi
    done
}

# Copy a template file to destination.
# In create-if-missing mode (default): skip if dest exists.
# In update mode (--update-templates): backup and overwrite.
install_file() {
    local src="$1"
    local dest="$2"
    local owner="$3"
    local perms="${4:-644}"

    if [ -f "$dest" ] && [ "$UPDATE_TEMPLATES" != "true" ]; then
        log_skipped "$dest (already exists)"
        COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
        return
    fi

    if [ -f "$dest" ] && [ "$UPDATE_TEMPLATES" = "true" ]; then
        cp "$dest" "${dest}.bak.${TIMESTAMP}"
        log_updated "$dest (backup: ${dest}.bak.${TIMESTAMP})"
        COUNT_UPDATED=$((COUNT_UPDATED + 1))
    else
        log_created "$dest"
        COUNT_CREATED=$((COUNT_CREATED + 1))
    fi

    cp "$src" "$dest"
    chown "$owner:$owner" "$dest"
    chmod "$perms" "$dest"
}

# Run a command as the target user via bash login shell
run_as_user() {
    local username="$1"
    shift
    su - "$username" -c "bash -c 'source \"\$HOME/.nvm/nvm.sh\" 2>/dev/null; $*'"
}

# --- Parse arguments ---

USERNAME=""
GIT_NAME=""
GIT_EMAIL=""
WITH_OLLAMA=false
OLLAMA_HOST="$DEFAULT_OLLAMA_HOST"
WITH_SOUNDS=false
COPY_ADMIN_CREDS=false
UPDATE_TEMPLATES=false

parse_args() {
    if [ $# -lt 1 ]; then
        echo "Usage: sudo $0 <username> [--git-name \"Name\"] [--git-email \"email\"] [--with-ollama] [--ollama-host \"host:port\"] [--with-sounds] [--copy-admin-credentials] [--update-templates]"
        exit 1
    fi

    USERNAME="$1"
    shift

    while [ $# -gt 0 ]; do
        case "$1" in
            --git-name)
                GIT_NAME="$2"
                shift 2
                ;;
            --git-email)
                GIT_EMAIL="$2"
                shift 2
                ;;
            --with-ollama)
                WITH_OLLAMA=true
                shift
                ;;
            --ollama-host)
                WITH_OLLAMA=true
                OLLAMA_HOST="$2"
                shift 2
                ;;
            --with-sounds)
                WITH_SOUNDS=true
                shift
                ;;
            --copy-admin-credentials)
                COPY_ADMIN_CREDS=true
                shift
                ;;
            --update-templates)
                UPDATE_TEMPLATES=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

# --- Main steps ---

step_create_user() {
    log_section "User account"

    if id "$USERNAME" >/dev/null 2>&1; then
        log_skipped "User '$USERNAME' already exists"
        COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
    else
        useradd -m -s /bin/bash "$USERNAME"
        log_created "User '$USERNAME'"
        COUNT_CREATED=$((COUNT_CREATED + 1))
    fi
}

step_docker_group() {
    if id -nG "$USERNAME" | grep -qw docker; then
        log_skipped "User '$USERNAME' already in docker group"
        COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
    else
        usermod -aG docker "$USERNAME"
        log_created "Added '$USERNAME' to docker group"
        COUNT_CREATED=$((COUNT_CREATED + 1))
    fi
}

step_install_dotfiles() {
    log_section "Dotfiles"

    local home="/home/$USERNAME"

    # bashrc
    install_file "$TEMPLATES_DIR/bashrc.template" "$home/.bashrc" "$USERNAME" 644

    # profile
    install_file "$TEMPLATES_DIR/profile.template" "$home/.profile" "$USERNAME" 644

    # tmux.conf
    install_file "$TEMPLATES_DIR/tmux.conf.template" "$home/.tmux.conf" "$USERNAME" 644

    # gitconfig (needs placeholder substitution)
    if [ -f "$home/.gitconfig" ] && [ "$UPDATE_TEMPLATES" != "true" ]; then
        log_skipped "$home/.gitconfig (already exists)"
        COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
    else
        if [ -z "$GIT_NAME" ] || [ -z "$GIT_EMAIL" ]; then
            if [ ! -f "$home/.gitconfig" ]; then
                log_warning ".gitconfig requires --git-name and --git-email on first run"
                COUNT_WARNINGS=$((COUNT_WARNINGS + 1))
            else
                log_skipped "$home/.gitconfig (no --git-name/--git-email provided, keeping existing)"
                COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
            fi
        else
            if [ -f "$home/.gitconfig" ] && [ "$UPDATE_TEMPLATES" = "true" ]; then
                cp "$home/.gitconfig" "$home/.gitconfig.bak.${TIMESTAMP}"
                log_updated "$home/.gitconfig (backup created)"
                COUNT_UPDATED=$((COUNT_UPDATED + 1))
            else
                log_created "$home/.gitconfig"
                COUNT_CREATED=$((COUNT_CREATED + 1))
            fi
            sed -e "s/{{GIT_NAME}}/$GIT_NAME/g" \
                -e "s/{{GIT_EMAIL}}/$GIT_EMAIL/g" \
                "$TEMPLATES_DIR/gitconfig.template" > "$home/.gitconfig"
            chown "$USERNAME:$USERNAME" "$home/.gitconfig"
            chmod 644 "$home/.gitconfig"
        fi
    fi
}

step_install_nvm_node() {
    log_section "NVM + Node.js"

    local home="/home/$USERNAME"

    if [ -d "$home/.nvm" ]; then
        log_skipped "NVM already installed at $home/.nvm/"
        COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
    else
        echo "  Installing NVM ${NVM_VERSION}..."
        su - "$USERNAME" -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash" >/dev/null 2>&1
        log_created "NVM ${NVM_VERSION}"
        COUNT_CREATED=$((COUNT_CREATED + 1))

        echo "  Installing Node.js LTS..."
        su - "$USERNAME" -c 'bash -c "source \"\$HOME/.nvm/nvm.sh\" && nvm install --lts"' >/dev/null 2>&1
        log_created "Node.js LTS"
        COUNT_CREATED=$((COUNT_CREATED + 1))
    fi
}

step_install_pnpm() {
    if run_as_user "$USERNAME" "command -v pnpm" >/dev/null 2>&1; then
        log_skipped "pnpm already installed"
        COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
    else
        echo "  Installing pnpm..."
        run_as_user "$USERNAME" "npm install -g pnpm" >/dev/null 2>&1
        log_created "pnpm"
        COUNT_CREATED=$((COUNT_CREATED + 1))
    fi
}

step_install_claude() {
    log_section "Claude Code"

    if run_as_user "$USERNAME" "command -v claude" >/dev/null 2>&1; then
        log_skipped "Claude Code already installed"
        COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
    else
        echo "  Installing Claude Code (@anthropic-ai/claude-code)..."
        run_as_user "$USERNAME" "npm install -g @anthropic-ai/claude-code" >/dev/null 2>&1
        log_created "Claude Code"
        COUNT_CREATED=$((COUNT_CREATED + 1))
    fi
}

step_claude_config() {
    log_section "Claude Code config"

    local home="/home/$USERNAME"
    local claude_dir="$home/.claude"

    mkdir -p "$claude_dir"
    chown "$USERNAME:$USERNAME" "$claude_dir"
    chmod 700 "$claude_dir"

    # CLAUDE.md
    install_file "$TEMPLATES_DIR/claude/CLAUDE.md.template" "$claude_dir/CLAUDE.md" "$USERNAME" 644

    # settings.json (base or sounds version)
    if [ "$WITH_SOUNDS" = "true" ]; then
        install_file "$TEMPLATES_DIR/claude/settings.sounds.json.template" "$claude_dir/settings.json" "$USERNAME" 644

        # Copy sound scripts
        mkdir -p "$claude_dir/sounds"
        chown "$USERNAME:$USERNAME" "$claude_dir/sounds"
        cp "$TEMPLATES_DIR/claude/sounds/play-remote.sh" "$claude_dir/sounds/"
        cp "$TEMPLATES_DIR/claude/sounds/play-error-remote.sh" "$claude_dir/sounds/"
        chown -R "$USERNAME:$USERNAME" "$claude_dir/sounds"
        chmod 755 "$claude_dir/sounds/"*.sh
        log_created "Claude Code sound hooks"
        COUNT_CREATED=$((COUNT_CREATED + 1))
    else
        install_file "$TEMPLATES_DIR/claude/settings.json.template" "$claude_dir/settings.json" "$USERNAME" 644
    fi

    # --copy-admin-credentials
    if [ "$COPY_ADMIN_CREDS" = "true" ]; then
        local admin_user="${SUDO_USER:-}"
        local admin_creds="/home/$admin_user/.claude/.credentials.json"
        local dest_creds="$claude_dir/.credentials.json"

        if [ -z "$admin_user" ]; then
            log_warning "--copy-admin-credentials: cannot determine admin user (\$SUDO_USER is empty)"
            COUNT_WARNINGS=$((COUNT_WARNINGS + 1))
        elif [ ! -f "$admin_creds" ]; then
            log_warning "--copy-admin-credentials: $admin_creds not found"
            COUNT_WARNINGS=$((COUNT_WARNINGS + 1))
        elif [ -f "$dest_creds" ]; then
            log_skipped "$dest_creds (already exists, not overwriting credentials)"
            COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
        else
            cp "$admin_creds" "$dest_creds"
            chown "$USERNAME:$USERNAME" "$dest_creds"
            chmod 600 "$dest_creds"
            log_created "$dest_creds (copied from $admin_user)"
            COUNT_CREATED=$((COUNT_CREATED + 1))
        fi
    fi
}

step_directories() {
    log_section "Directories"

    local home="/home/$USERNAME"
    local dirs=("$home/src" "$home/runtime" "$home/.local/bin")

    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            log_skipped "$dir/ (already exists)"
            COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
        else
            mkdir -p "$dir"
            chown "$USERNAME:$USERNAME" "$dir"
            log_created "$dir/"
            COUNT_CREATED=$((COUNT_CREATED + 1))
        fi
    done

    # Ensure .local is owned correctly
    chown "$USERNAME:$USERNAME" "$home/.local" 2>/dev/null || true
}

step_ssh_key() {
    log_section "SSH key"

    local home="/home/$USERNAME"
    local ssh_dir="$home/.ssh"
    local key_file="$ssh_dir/id_ed25519"

    if [ -f "$key_file" ]; then
        log_skipped "SSH key already exists at $key_file"
        COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
    else
        mkdir -p "$ssh_dir"
        chown "$USERNAME:$USERNAME" "$ssh_dir"
        chmod 700 "$ssh_dir"

        ssh-keygen -t ed25519 -f "$key_file" -N "" -C "${USERNAME}@dev-vm" >/dev/null 2>&1
        chown "$USERNAME:$USERNAME" "$key_file" "$key_file.pub"
        chmod 600 "$key_file"
        chmod 644 "$key_file.pub"
        log_created "SSH key ($key_file)"
        COUNT_CREATED=$((COUNT_CREATED + 1))

        echo ""
        echo "  Public key (copy to other machines as needed):"
        echo "  $(cat "$key_file.pub")"
    fi
}

step_ollama() {
    if [ "$WITH_OLLAMA" != "true" ]; then
        return
    fi

    log_section "Ollama (shared service)"

    local home="/home/$USERNAME"
    local bashrc="$home/.bashrc"

    if grep -q "OLLAMA_HOST" "$bashrc" 2>/dev/null; then
        log_skipped "OLLAMA_HOST already in .bashrc"
        COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
    else
        echo "" >> "$bashrc"
        echo "# Ollama (shared service)" >> "$bashrc"
        echo "export OLLAMA_HOST=\"${OLLAMA_HOST}\"" >> "$bashrc"
        log_created "OLLAMA_HOST=${OLLAMA_HOST} added to .bashrc"
        COUNT_CREATED=$((COUNT_CREATED + 1))
    fi
}

step_permissions() {
    log_section "Permissions"

    local home="/home/$USERNAME"

    chmod 750 "$home"
    [ -d "$home/.ssh" ] && chmod 700 "$home/.ssh"
    [ -d "$home/.claude" ] && chmod 700 "$home/.claude"
    [ -f "$home/.claude/.credentials.json" ] && chmod 600 "$home/.claude/.credentials.json"

    log_skipped "Permissions verified"
    COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
}

step_verify() {
    log_section "Verification"

    local home="/home/$USERNAME"
    local failures=()

    # Check node
    if run_as_user "$USERNAME" "node --version" >/dev/null 2>&1; then
        local node_ver
        node_ver=$(run_as_user "$USERNAME" "node --version" 2>/dev/null)
        echo -e "  ${GREEN}[PASS]${NC} Node.js $node_ver"
    else
        echo -e "  ${RED}[FAIL]${NC} Node.js not available"
        failures+=("node")
    fi

    # Check npm
    if run_as_user "$USERNAME" "npm --version" >/dev/null 2>&1; then
        echo -e "  ${GREEN}[PASS]${NC} npm $(run_as_user "$USERNAME" "npm --version" 2>/dev/null)"
    else
        echo -e "  ${RED}[FAIL]${NC} npm not available"
        failures+=("npm")
    fi

    # Check pnpm
    if run_as_user "$USERNAME" "pnpm --version" >/dev/null 2>&1; then
        echo -e "  ${GREEN}[PASS]${NC} pnpm $(run_as_user "$USERNAME" "pnpm --version" 2>/dev/null)"
    else
        echo -e "  ${RED}[FAIL]${NC} pnpm not available"
        failures+=("pnpm")
    fi

    # Check claude
    if run_as_user "$USERNAME" "claude --version" >/dev/null 2>&1; then
        echo -e "  ${GREEN}[PASS]${NC} Claude Code $(run_as_user "$USERNAME" "claude --version" 2>/dev/null)"
    else
        echo -e "  ${RED}[FAIL]${NC} Claude Code not available"
        failures+=("claude")
    fi

    # Check git config
    if [ -f "$home/.gitconfig" ]; then
        local git_name
        git_name=$(run_as_user "$USERNAME" "git config user.name" 2>/dev/null || true)
        if [ -n "$git_name" ]; then
            echo -e "  ${GREEN}[PASS]${NC} git config (user: $git_name)"
        else
            echo -e "  ${RED}[FAIL]${NC} git config exists but user.name is empty"
            failures+=("git-config")
        fi
    else
        echo -e "  ${RED}[FAIL]${NC} .gitconfig missing"
        failures+=("git-config")
    fi

    # Check tmux
    if [ -f "$home/.tmux.conf" ]; then
        echo -e "  ${GREEN}[PASS]${NC} tmux config"
    else
        echo -e "  ${RED}[FAIL]${NC} .tmux.conf missing"
        failures+=("tmux-config")
    fi

    # Check docker group
    if id -nG "$USERNAME" 2>/dev/null | grep -qw docker; then
        echo -e "  ${GREEN}[PASS]${NC} docker group"
    else
        echo -e "  ${RED}[FAIL]${NC} not in docker group"
        failures+=("docker-group")
    fi

    # Check directories
    for dir in "$home/src" "$home/runtime" "$home/.local/bin"; do
        if [ -d "$dir" ]; then
            echo -e "  ${GREEN}[PASS]${NC} $dir/"
        else
            echo -e "  ${RED}[FAIL]${NC} $dir/ missing"
            failures+=("dir:$dir")
        fi
    done

    # Check SSH key
    if [ -f "$home/.ssh/id_ed25519" ]; then
        echo -e "  ${GREEN}[PASS]${NC} SSH key"
    else
        echo -e "  ${RED}[FAIL]${NC} SSH key missing"
        failures+=("ssh-key")
    fi

    # Check Claude config
    if [ -f "$home/.claude/CLAUDE.md" ]; then
        echo -e "  ${GREEN}[PASS]${NC} Claude CLAUDE.md"
    else
        echo -e "  ${RED}[FAIL]${NC} Claude CLAUDE.md missing"
        failures+=("claude-config")
    fi

    # Check permissions
    local home_perms
    home_perms=$(stat -c "%a" "$home" 2>/dev/null)
    if [ "$home_perms" = "750" ]; then
        echo -e "  ${GREEN}[PASS]${NC} home permissions ($home_perms)"
    else
        echo -e "  ${RED}[FAIL]${NC} home permissions ($home_perms, expected 750)"
        failures+=("permissions")
    fi

    # Store failures for diagnose step
    VERIFY_FAILURES=("${failures[@]}")

    echo ""
    if [ ${#failures[@]} -eq 0 ]; then
        echo -e "  ${GREEN}All checks passed.${NC}"
    else
        echo -e "  ${RED}${#failures[@]} check(s) failed: ${failures[*]}${NC}"
    fi
}

step_diagnose() {
    # Only run if verify found failures
    if [ ${#VERIFY_FAILURES[@]} -eq 0 ]; then
        return
    fi

    log_section "Diagnosis (Claude Code CLI)"

    # Check that claude is available to the admin (the one running sudo)
    local admin_user="${SUDO_USER:-}"
    if [ -z "$admin_user" ]; then
        log_warning "Cannot run diagnosis: \$SUDO_USER is empty"
        COUNT_WARNINGS=$((COUNT_WARNINGS + 1))
        return
    fi

    if ! su - "$admin_user" -c "command -v claude" >/dev/null 2>&1; then
        log_warning "Cannot run diagnosis: claude not found for admin user '$admin_user'"
        COUNT_WARNINGS=$((COUNT_WARNINGS + 1))
        return
    fi

    local home="/home/$USERNAME"
    local failed_list="${VERIFY_FAILURES[*]}"

    echo "  Launching Claude Code to diagnose failures: $failed_list"
    echo ""

    # Build diagnosis prompt
    local prompt="You are diagnosing a failed dev environment provisioning for user '$USERNAME' on Ubuntu 22.04 (dev-vm).

The following verification checks FAILED: $failed_list

The user's home directory is: $home

Please investigate each failure:
1. Check if the relevant files/tools exist and their state
2. Check permissions and ownership
3. Identify the root cause of each failure
4. Suggest specific fix commands

Be concise. Output a short summary per failure with the fix command.
Do NOT make any changes - only diagnose and report."

    # Run claude in print mode as the admin user, with read-only tools
    su - "$admin_user" -c "claude -p $(printf '%q' "$prompt") --dangerously-skip-permissions --allowedTools 'Bash,Read,Glob,Grep' --no-session-persistence" 2>/dev/null || {
        log_warning "Claude Code diagnosis exited with an error"
        COUNT_WARNINGS=$((COUNT_WARNINGS + 1))
    }

    echo ""
}

print_summary() {
    echo ""
    echo -e "${GREEN}=============================${NC}"
    echo -e "${GREEN}  spawn-user.sh complete${NC}"
    echo -e "${GREEN}=============================${NC}"
    echo ""
    echo -e "  User:     ${BLUE}${USERNAME}${NC}"
    echo -e "  Home:     /home/${USERNAME}"
    echo -e "  Created:  ${GREEN}${COUNT_CREATED}${NC}"
    echo -e "  Updated:  ${YELLOW}${COUNT_UPDATED}${NC}"
    echo -e "  Skipped:  ${BLUE}${COUNT_SKIPPED}${NC}"
    echo -e "  Warnings: ${YELLOW}${COUNT_WARNINGS}${NC}"

    if [ ${#VERIFY_FAILURES[@]} -eq 0 ]; then
        echo -e "  Verify:   ${GREEN}ALL PASSED${NC}"
    else
        echo -e "  Verify:   ${RED}${#VERIFY_FAILURES[@]} FAILED${NC}"
    fi

    echo ""

    if [ "$COUNT_WARNINGS" -gt 0 ]; then
        echo -e "  ${YELLOW}Review warnings above.${NC}"
    fi

    echo "  To login as this user: su - $USERNAME"
    echo ""
}

# --- Main ---

VERIFY_FAILURES=()

main() {
    parse_args "$@"

    echo -e "${GREEN}dev-spawner${NC} — provisioning user '${USERNAME}'"
    echo ""

    check_root
    check_prerequisites
    check_network
    validate_username "$USERNAME"

    step_create_user
    step_docker_group
    step_install_dotfiles
    step_install_nvm_node
    step_install_pnpm
    step_install_claude
    step_claude_config
    step_directories
    step_ssh_key
    step_ollama
    step_permissions
    step_verify
    step_diagnose
    print_summary
}

main "$@"
