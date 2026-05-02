 #!/bin/bash
# =============================================================================
#  Sudosoc-Env Pro — Installer / Uninstaller
#  Usage:  sudo bash install.sh
#          sudo bash install.sh --uninstall
# =============================================================================

# ── Color Palette ─────────────────────────────────────────────────────────────
C_RESET="\e[0m"
C_BOLD="\e[1m"
C_GREEN="\e[32m"
C_CYAN="\e[36m"
C_YELLOW="\e[33m"
C_RED="\e[31m"
C_DIM="\e[2m"
C_PURPLE="\e[35m"

# ── Print Helpers ──────────────────────────────────────────────────────────────
banner() {
    echo -e ""
    echo -e "${C_PURPLE}${C_BOLD}  ╔══════════════════════════════════════════════════╗${C_RESET}"
    echo -e "${C_PURPLE}${C_BOLD}  ║   🚀  Sudosoc-Env Pro  ·  Installer v3.0        ║${C_RESET}"
    echo -e "${C_PURPLE}${C_BOLD}  ╚══════════════════════════════════════════════════╝${C_RESET}"
    echo -e ""
}

step()    { echo -e "${C_CYAN}${C_BOLD}  ──▶  $*${C_RESET}"; }
ok()      { echo -e "${C_GREEN}  ✅  $*${C_RESET}"; }
info()    { echo -e "${C_YELLOW}  ℹ️   $*${C_RESET}"; }
skip()    { echo -e "${C_DIM}  ⏭️   $* (already done)${C_RESET}"; }
fatal()   { echo -e "${C_RED}${C_BOLD}  ❌  FATAL: $*${C_RESET}" >&2; exit 1; }
warn()    { echo -e "${C_YELLOW}  ⚠️   $*${C_RESET}"; }
divider() { echo -e "${C_DIM}  ──────────────────────────────────────────────────${C_RESET}"; }

# ── Parse CLI flags ────────────────────────────────────────────────────────────
MODE="install"
for arg in "$@"; do
    case "$arg" in
        --uninstall|-u) MODE="uninstall" ;;
        --help|-h)
            echo "Usage:  sudo bash install.sh [--uninstall]"
            echo ""
            echo "  (no flags)    Install Sudosoc-Env Pro"
            echo "  --uninstall   Remove all installed files and shell config lines"
            exit 0 ;;
        *)
            echo -e "${C_RED}Unknown flag: $arg${C_RESET}" >&2
            echo "Run with --help for usage." >&2
            exit 1 ;;
    esac
done

# =============================================================================
# SECTION 1: Pre-flight Checks
# =============================================================================
banner

step "Running pre-flight checks..."

# 1a. Root privilege check
# The script must be run with sudo to write to /usr/local/bin and /etc
if [[ "$EUID" -ne 0 ]]; then
    fatal "This script must be run as root.\n\n      Run: ${C_CYAN}sudo bash install.sh${C_RESET}"
fi
ok "Running as root"

# 1b. Real user detection
# $SUDO_USER holds the name of the user who called sudo.
# We never use root's $HOME — all user files go to the real user's home.
if [[ -z "${SUDO_USER:-}" ]]; then
    fatal "\$SUDO_USER is not set.\n\n      Please use 'sudo bash install.sh' (not 'su -c ...' or 'sudo su')"
fi
ok "Real user detected: ${C_BOLD}${SUDO_USER}${C_RESET}"

# 1c. Resolve the real user's home directory and default shell from /etc/passwd.
#     We use 'getent passwd' which works for local users, LDAP, and NIS users.
#     Fallback to a direct /etc/passwd grep for systems without getent.
_PASSWD_ENTRY=""
if command -v getent &>/dev/null; then
    _PASSWD_ENTRY=$(getent passwd "$SUDO_USER")
else
    _PASSWD_ENTRY=$(grep "^${SUDO_USER}:" /etc/passwd)
fi

if [[ -z "$_PASSWD_ENTRY" ]]; then
    fatal "Could not find user '${SUDO_USER}' in the password database."
fi

# Field 6 = home directory,  Field 7 = login shell
REAL_HOME=$(echo "$_PASSWD_ENTRY" | cut -d: -f6)
REAL_SHELL=$(echo "$_PASSWD_ENTRY" | cut -d: -f7)
SHELL_NAME=$(basename "$REAL_SHELL")   # e.g. "bash" or "zsh"

ok "Home directory  : ${C_BOLD}${REAL_HOME}${C_RESET}"
ok "Default shell   : ${C_BOLD}${SHELL_NAME}${C_RESET}  (${REAL_SHELL})"

# 1d. Verify that the required source files sit next to this installer
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_MAIN="${SCRIPT_DIR}/sudosoc-env.sh"
SRC_BASH="${SCRIPT_DIR}/sudosoc-env-completion.bash"
SRC_ZSH="${SCRIPT_DIR}/sudosoc-env-completion.zsh"

for f in "$SRC_MAIN" "$SRC_BASH" "$SRC_ZSH"; do
    [[ -f "$f" ]] || fatal "Required file not found: ${f}\n\n      Make sure install.sh is in the same directory as the Sudosoc-Env Pro files."
done
ok "All source files found"
divider

# =============================================================================
# SECTION 2: Uninstall Mode
# =============================================================================
if [[ "$MODE" == "uninstall" ]]; then
    step "Uninstalling Sudosoc-Env Pro..."
    echo ""

    # Remove binary
    if [[ -f "/usr/local/bin/sudosoc-env" ]]; then
        rm -f "/usr/local/bin/sudosoc-env"
        ok "Removed /usr/local/bin/sudosoc-env"
    else
        skip "/usr/local/bin/sudosoc-env not found"
    fi

    # Remove completion files
    if [[ -d "${REAL_HOME}/.sudosoc" ]]; then
        rm -rf "${REAL_HOME}/.sudosoc"
        ok "Removed ${REAL_HOME}/.sudosoc/"
    else
        skip "${REAL_HOME}/.sudosoc/ not found"
    fi

    # Remove shell config lines from .bashrc and .zshrc (both, in case they
    # were added during an install with a different shell)
    for rc in "${REAL_HOME}/.bashrc" "${REAL_HOME}/.zshrc"; do
        if [[ -f "$rc" ]]; then
            # Create a backup before modifying
            cp "$rc" "${rc}.sudosoc.bak"
            # Remove the three lines we added (SUDOSOC_HOME export,
            # source line, and the blank separator comment)
            sed -i '/# Added by Sudosoc-Env Pro installer/d' "$rc"
            sed -i '/SUDOSOC_HOME=.*\.sudosoc_envs/d' "$rc"
            sed -i '/source.*sudosoc-env-completion/d' "$rc"
            ok "Cleaned ${rc}  ${C_DIM}(backup: ${rc}.sudosoc.bak)${C_RESET}"
        fi
    done

    # Note: We intentionally leave ~/.sudosoc_envs intact.
    # The user's virtual environments are their data — we never delete those.
    warn "Your environments in ${REAL_HOME}/.sudosoc_envs were NOT deleted."
    info "Remove them manually if needed: rm -rf ${REAL_HOME}/.sudosoc_envs"
    echo ""
    echo -e "${C_GREEN}${C_BOLD}  Sudosoc-Env Pro has been uninstalled.${C_RESET}"
    echo ""
    exit 0
fi

# =============================================================================
# SECTION 3: Install — Step 1: Binary
# Copy the main script to /usr/local/bin so it's on every user's PATH
# =============================================================================
echo ""
step "Step 1/4  ·  Installing binary → /usr/local/bin/sudosoc-env"

BIN_DEST="/usr/local/bin/sudosoc-env"

cp "$SRC_MAIN" "$BIN_DEST"
chmod +x "$BIN_DEST"
# The binary is owned by root but executable by all — standard for system tools
chown root:root "$BIN_DEST" 2>/dev/null || true
ok "Installed : ${BIN_DEST}"
ok "Permission: $(ls -l "$BIN_DEST" | awk '{print $1, $3, $4}')"
divider

# =============================================================================
# SECTION 4: Install — Step 2: Central Environment Directory
# Create ~/.sudosoc_envs (SUDOSOC_HOME) and ensure the real user owns it
# =============================================================================
echo ""
step "Step 2/4  ·  Creating SUDOSOC_HOME directory"

ENVS_DIR="${REAL_HOME}/.sudosoc_envs"

if [[ ! -d "$ENVS_DIR" ]]; then
    mkdir -p "$ENVS_DIR"
    ok "Created : ${ENVS_DIR}"
else
    skip "${ENVS_DIR}"
fi

# Fix ownership — the directory must belong to the real user, not root
chown -R "${SUDO_USER}:${SUDO_USER}" "$ENVS_DIR" 2>/dev/null \
    || chown -R "${SUDO_USER}" "$ENVS_DIR" 2>/dev/null \
    || warn "Could not set ownership on ${ENVS_DIR} — fix manually: chown -R ${SUDO_USER} ${ENVS_DIR}"
ok "Ownership : ${SUDO_USER}:${SUDO_USER}"
divider

# =============================================================================
# SECTION 5: Install — Step 3: Completion Files
# Place both completion files in ~/.sudosoc/ so the user can source either one
# =============================================================================
echo ""
step "Step 3/4  ·  Installing completion files → ${REAL_HOME}/.sudosoc/"

SUDOSOC_DIR="${REAL_HOME}/.sudosoc"
mkdir -p "$SUDOSOC_DIR"

cp "$SRC_BASH" "${SUDOSOC_DIR}/sudosoc-env-completion.bash"
cp "$SRC_ZSH"  "${SUDOSOC_DIR}/sudosoc-env-completion.zsh"

# Fix ownership so the user can manage these files without sudo
chown -R "${SUDO_USER}:${SUDO_USER}" "$SUDOSOC_DIR" 2>/dev/null \
    || chown -R "${SUDO_USER}" "$SUDOSOC_DIR" 2>/dev/null

ok "Installed : ${SUDOSOC_DIR}/sudosoc-env-completion.bash"
ok "Installed : ${SUDOSOC_DIR}/sudosoc-env-completion.zsh"
divider

# =============================================================================
# SECTION 6: Install — Step 4: Shell Configuration
#
# Detect the user's shell from /etc/passwd (already resolved above as
# $SHELL_NAME). Append SUDOSOC_HOME export and the matching source line
# to the appropriate rc file. Check for duplicates before writing.
# =============================================================================
echo ""
step "Step 4/4  ·  Configuring shell (${SHELL_NAME})"

# Decide which rc file to update based on the user's login shell
case "$SHELL_NAME" in
    zsh)
        RC_FILE="${REAL_HOME}/.zshrc"
        SOURCE_LINE="source \"\${HOME}/.sudosoc/sudosoc-env-completion.zsh\""
        ;;
    bash)
        RC_FILE="${REAL_HOME}/.bashrc"
        SOURCE_LINE="source \"\${HOME}/.sudosoc/sudosoc-env-completion.bash\""
        ;;
    *)
        # Unknown shell — inform the user what to add manually and skip
        warn "Unrecognized shell '${SHELL_NAME}'."
        info "Add these lines to your shell's rc file manually:"
        echo -e "${C_DIM}"
        echo "  export SUDOSOC_HOME=\"\$HOME/.sudosoc_envs\""
        echo "  source \"\$HOME/.sudosoc/sudosoc-env-completion.bash\"  # or .zsh"
        echo -e "${C_RESET}"
        divider
        RC_FILE=""
        ;;
esac

if [[ -n "$RC_FILE" ]]; then
    # Create the rc file if it doesn't exist yet (e.g., fresh user account)
    if [[ ! -f "$RC_FILE" ]]; then
        touch "$RC_FILE"
        chown "${SUDO_USER}:${SUDO_USER}" "$RC_FILE" 2>/dev/null \
            || chown "${SUDO_USER}" "$RC_FILE" 2>/dev/null
        info "Created ${RC_FILE} (did not exist)"
    fi

    # ── Append SUDOSOC_HOME export (only if not already present) ──────────────
    EXPORT_LINE="export SUDOSOC_HOME=\"\$HOME/.sudosoc_envs\""

    if grep -qF 'SUDOSOC_HOME' "$RC_FILE"; then
        skip "SUDOSOC_HOME already set in ${RC_FILE}"
    else
        {
            echo ""
            echo "# Added by Sudosoc-Env Pro installer"
            echo "$EXPORT_LINE"
        } >> "$RC_FILE"
        ok "Appended SUDOSOC_HOME export → ${RC_FILE}"
    fi

    # ── Append completion source line (only if not already present) ───────────
    if grep -qF 'sudosoc-env-completion' "$RC_FILE"; then
        skip "Completion source already in ${RC_FILE}"
    else
        echo "$SOURCE_LINE" >> "$RC_FILE"
        ok "Appended completion source  → ${RC_FILE}"
    fi

    # Fix ownership of the rc file in case it was created/touched as root
    chown "${SUDO_USER}:${SUDO_USER}" "$RC_FILE" 2>/dev/null \
        || chown "${SUDO_USER}" "$RC_FILE" 2>/dev/null
fi

divider

# =============================================================================
# SECTION 7: Verify Installation
# Quick sanity-check — make sure the binary is executable and reachable
# =============================================================================
echo ""
step "Verifying installation..."

if [[ -x "/usr/local/bin/sudosoc-env" ]]; then
    ok "Binary reachable at /usr/local/bin/sudosoc-env"
else
    warn "Binary not found or not executable at /usr/local/bin/sudosoc-env"
fi

if [[ -d "$ENVS_DIR" ]]; then
    ok "SUDOSOC_HOME directory exists: ${ENVS_DIR}"
fi

if [[ -f "${SUDOSOC_DIR}/sudosoc-env-completion.${SHELL_NAME}" ]] || \
   [[ -f "${SUDOSOC_DIR}/sudosoc-env-completion.bash" ]]; then
    ok "Completion files in place: ${SUDOSOC_DIR}/"
fi

# =============================================================================
# SECTION 8: Summary
# =============================================================================
echo ""
echo -e "${C_GREEN}${C_BOLD}  ╔══════════════════════════════════════════════════╗${C_RESET}"
echo -e "${C_GREEN}${C_BOLD}  ║   ✅  Installation Complete!                     ║${C_RESET}"
echo -e "${C_GREEN}${C_BOLD}  ╚══════════════════════════════════════════════════╝${C_RESET}"
echo ""
echo -e "${C_BOLD}  What was installed:${C_RESET}"
echo -e "  ${C_DIM}Binary    ${C_RESET}→  /usr/local/bin/sudosoc-env"
echo -e "  ${C_DIM}Home dir  ${C_RESET}→  ${ENVS_DIR}"
echo -e "  ${C_DIM}Completion${C_RESET}→  ${SUDOSOC_DIR}/"
[[ -n "${RC_FILE:-}" ]] && \
echo -e "  ${C_DIM}Shell cfg ${C_RESET}→  ${RC_FILE}"
echo ""
echo -e "${C_BOLD}  To start using Sudosoc-Env Pro:${C_RESET}"
echo ""
echo -e "  ${C_CYAN}1.${C_RESET}  Reload your shell config:"
if [[ "$SHELL_NAME" == "zsh" ]]; then
    echo -e "       ${C_YELLOW}source ~/.zshrc${C_RESET}"
else
    echo -e "       ${C_YELLOW}source ~/.bashrc${C_RESET}"
fi
echo ""
echo -e "  ${C_CYAN}2.${C_RESET}  Create your first environment:"
echo -e "       ${C_YELLOW}sudosoc-env my-project${C_RESET}"
echo ""
echo -e "  ${C_CYAN}3.${C_RESET}  See all commands:"
echo -e "       ${C_YELLOW}sudosoc-env --help${C_RESET}"
echo ""
echo -e "  ${C_CYAN}4.${C_RESET}  To uninstall later:"
echo -e "       ${C_YELLOW}sudo bash install.sh --uninstall${C_RESET}"
echo ""
