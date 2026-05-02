#!/bin/bash
# =============================================================================
# Sudosoc-Env Pro v3.0 — Advanced Python Virtual Environment Manager
# Author  : SUDOSOC
# =============================================================================
# New in v3.0:
#   CLI    : SUDOSOC_HOME, --global-list, --version-pin, --theme, --home,
#             --local, pyenv integration, lazy pip upgrade, hooks system,
#             history log
#   Internal: sudosoc-clone, sudosoc-doctor, sudosoc-lock, sudosoc-search,
#             sudosoc-note, sudosoc-docker, sudosoc-bench
#   Extra  : Tab completion (see sudosoc-env-completion.bash/.zsh)
# =============================================================================

VERSION="3.0.0"

# =============================================================================
# SECTION 0: Default Configuration
# =============================================================================
INSTALL_REQ=0
ENV_NAME=""
ACTIVATE_ONLY=0
PYTHON_CMD="python3"
ACTION="create"
CONFIRM_DELETE=0
NO_SYSTEM_PKGS=0
VERSION_PIN=0           # [--version-pin] Also write requirements.lock on save
THEME="classic"         # [--theme]       PS1 color theme
USE_HOME=0              # [--home]        Store env in SUDOSOC_HOME
USE_LOCAL=0             # [--local]       Force current directory

# SUDOSOC_HOME: central store for all envs (respects env-var if set)
SUDOSOC_HOME_DIR="${SUDOSOC_HOME:-${HOME}/.sudosoc_envs}"

# History file and lazy-upgrade interval (7 days in seconds)
HISTORY_FILE="${HOME}/.sudosoc_history"
PIP_UPGRADE_INTERVAL=$((7 * 24 * 3600))

# =============================================================================
# SECTION 1: Helper Functions (used by the outer script, not the subshell)
# =============================================================================

# Append a timestamped entry to the history file
log_history() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $1 | ${2:-}" >> "$HISTORY_FILE"
}

# Execute a lifecycle hook if it exists and is executable
# Usage: run_hook <hook_name> <env_path>
run_hook() {
    local hook_file="${2}/.sudosoc/${1}.sh"
    if [[ -f "$hook_file" && -x "$hook_file" ]]; then
        echo -e "\e[90m🪝 Running hook: ${1}.sh\e[0m"
        bash "$hook_file"
    fi
}

# Upgrade pip only if it hasn't been upgraded in the last 7 days
do_lazy_pip_upgrade() {
    local marker="${FULL_PATH}/.pip_upgraded"
    local now; now=$(date +%s)
    if [[ -f "$marker" ]]; then
        local last; last=$(cat "$marker" 2>/dev/null || echo 0)
        if (( now - last < PIP_UPGRADE_INTERVAL )); then
            echo -e "\e[90m🔧 pip already upgraded recently — skipping.\e[0m"
            return 0
        fi
    fi
    echo -e "\e[90m🔧 Upgrading pip...\e[0m"
    "$FULL_PATH/bin/python" -m pip install --upgrade pip --quiet
    echo "$now" > "$marker"
}

# =============================================================================
# SECTION 2: Argument Parsing
# =============================================================================
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help)         ACTION="help";        shift ;;
        -v|--version)      ACTION="version";     shift ;;
        -l|--list)         ACTION="list";        shift ;;
        --global-list)     ACTION="global-list"; shift ;;

        -d|--delete)
            [[ -z "${2:-}" || "${2:-}" == -* ]] && { echo -e "\e[31m❌ --delete requires an env name.\e[0m" >&2; exit 1; }
            ACTION="delete"; ENV_NAME="$2"; shift 2 ;;

        -r|--requirements) INSTALL_REQ=1; shift ;;

        -p|--python)
            [[ -z "${2:-}" || "${2:-}" == -* ]] && { echo -e "\e[31m❌ --python requires a version string.\e[0m" >&2; exit 1; }
            PYTHON_CMD="$2"; shift 2 ;;

        -a|--activate)
            [[ -z "${2:-}" || "${2:-}" == -* ]] && { echo -e "\e[31m❌ --activate requires an env name.\e[0m" >&2; exit 1; }
            ACTIVATE_ONLY=1; ENV_NAME="$2"; shift 2 ;;

        --force)           CONFIRM_DELETE=1;  shift ;;
        --no-system-pkgs)  NO_SYSTEM_PKGS=1;  shift ;;
        --version-pin)     VERSION_PIN=1;     shift ;;
        --home)            USE_HOME=1;        shift ;;
        --local)           USE_LOCAL=1;       shift ;;

        --theme)
            [[ -z "${2:-}" || "${2:-}" == -* ]] && { echo -e "\e[31m❌ --theme requires a name (classic|minimal|neon|pastel).\e[0m" >&2; exit 1; }
            THEME="$2"; shift 2 ;;

        -*)
            echo -e "\e[31m❌ Unknown flag '$1'. Run --help for usage.\e[0m" >&2; exit 1 ;;

        *)
            [[ -n "$ENV_NAME" ]] && { echo -e "\e[31m❌ Unexpected extra argument '$1'.\e[0m" >&2; exit 1; }
            ENV_NAME="$1"; shift ;;
    esac
done

# =============================================================================
# SECTION 3: Venv Inception Guard
# (list, global-list, help, version are safe to run from inside an env)
# =============================================================================
SAFE_ACTIONS=("help" "version" "list" "global-list")
if [[ -n "${VIRTUAL_ENV:-}" ]] && [[ ! " ${SAFE_ACTIONS[*]} " =~ " ${ACTION} " ]]; then
    echo -e "\e[31m⚠️  Already inside: '$(basename "$VIRTUAL_ENV")'\e[0m" >&2
    echo -e "\e[33m💡 Run 'sudosoc-exit' or 'deactivate' to leave first.\e[0m"
    exit 1
fi

# =============================================================================
# SECTION 4: --version
# =============================================================================
if [[ "$ACTION" == "version" ]]; then
    echo -e "\e[36mSudosoc-Env Pro v${VERSION}\e[0m"
    exit 0
fi

# =============================================================================
# SECTION 5: --help
# =============================================================================
if [[ "$ACTION" == "help" ]]; then
    echo -e "\e[36m╔════════════════════════════════════════════════════════════╗\e[0m"
    echo -e "\e[36m║   🚀  Sudosoc-Env Pro v${VERSION} — Python Env Manager         ║\e[0m"
    echo -e "\e[36m╚════════════════════════════════════════════════════════════╝\e[0m"
    echo ""
    echo -e "\e[33mUsage:\e[0m  sudosoc-env [OPTIONS] <ENV_NAME>"
    echo ""
    echo -e "\e[33mCLI Options:\e[0m"
    echo -e "  -a, --activate  <name>    Activate an existing environment"
    echo -e "  -r, --requirements        Install requirements.txt on entry"
    echo -e "  -p, --python    <ver>     Python interpreter (e.g., python3.11)"
    echo -e "  -l, --list                List envs in current directory"
    echo -e "      --global-list         List all envs in SUDOSOC_HOME"
    echo -e "  -d, --delete    <name>    Delete env (asks for confirmation)"
    echo -e "      --force               Skip delete confirmation"
    echo -e "      --home                Create/find env in SUDOSOC_HOME"
    echo -e "      --local               Force current directory"
    echo -e "      --no-system-pkgs      Isolate from system site-packages"
    echo -e "      --version-pin         Also write requirements.lock on save"
    echo -e "      --theme   <name>      PS1 theme: classic | minimal | neon | pastel"
    echo -e "  -v, --version             Show version number"
    echo -e "  -h, --help                Show this help menu"
    echo ""
    echo -e "\e[33mEnvironment variable:\e[0m"
    echo -e "  SUDOSOC_HOME              Base dir for envs (default: ~/.sudosoc_envs)"
    echo -e "  Current: \e[32m${SUDOSOC_HOME_DIR}\e[0m"
    echo ""
    echo -e "\e[32mInternal Commands (available inside an active environment):\e[0m"
    echo -e "  sudosoc-exit              Deactivate and exit"
    echo -e "  sudosoc-save              Freeze local packages → requirements.txt"
    echo -e "  sudosoc-lock              Generate requirements.lock with exact pins"
    echo -e "  sudosoc-add  <pkg...>     Install package(s) and auto-save"
    echo -e "  sudosoc-reset             Uninstall all local packages"
    echo -e "  sudosoc-update            Upgrade all outdated packages"
    echo -e "  sudosoc-clone <name>      Clone current env to a new one"
    echo -e "  sudosoc-run               Auto-detect entry point and run"
    echo -e "  sudosoc-info              Show environment stats"
    echo -e "  sudosoc-check             List outdated packages"
    echo -e "  sudosoc-doctor            Run environment health check"
    echo -e "  sudosoc-search <pkg>      Search PyPI without leaving the shell"
    echo -e "  sudosoc-note  [text]      View or add a note to this environment"
    echo -e "  sudosoc-docker            Generate a Dockerfile for this project"
    echo -e "  sudosoc-bench             Run Python micro-benchmark"
    echo ""
    echo -e "\e[33mHooks (place executable scripts in <ENV>/.sudosoc/):\e[0m"
    echo -e "  on_create.sh    on_activate.sh    on_exit.sh"
    echo ""
    echo -e "\e[33mTab completion:\e[0m"
    echo -e "  source sudosoc-env-completion.bash   # bash"
    echo -e "  source sudosoc-env-completion.zsh    # zsh"
    exit 0
fi

# =============================================================================
# SECTION 6: --list
# =============================================================================
if [[ "$ACTION" == "list" ]]; then
    echo -e "\e[34m📂 Environments in '$(pwd)':\e[0m"
    found=0
    shopt -s nullglob
    for dir in */; do
        if [[ -f "${dir}bin/activate" ]]; then
            pkg_count=$(find "${dir}lib" -maxdepth 3 -name "METADATA" 2>/dev/null | wc -l)
            echo -e "  🟢 \e[32m${dir%/}\e[0m  \e[90m(${pkg_count} packages)\e[0m"
            found=1
        fi
    done
    shopt -u nullglob
    [[ $found -eq 0 ]] && echo -e "  \e[33mNo virtual environments found here.\e[0m"
    exit 0
fi

# =============================================================================
# SECTION 6b: --global-list
# Lists all environments stored in SUDOSOC_HOME
# =============================================================================
if [[ "$ACTION" == "global-list" ]]; then
    echo -e "\e[34m🌐 Global Environments in '${SUDOSOC_HOME_DIR}':\e[0m"
    if [[ ! -d "$SUDOSOC_HOME_DIR" ]]; then
        echo -e "  \e[33mSUDOSOC_HOME does not exist yet.\e[0m"
        echo -e "  \e[90mCreate your first global env with: sudosoc-env --home <name>\e[0m"
        exit 0
    fi
    found=0
    shopt -s nullglob
    for dir in "${SUDOSOC_HOME_DIR}/*/"; do
        if [[ -f "${dir}bin/activate" ]]; then
            pkg_count=$(find "${dir}lib" -maxdepth 3 -name "METADATA" 2>/dev/null | wc -l)
            py_ver=$("${dir}bin/python" --version 2>&1 | awk '{print $2}')
            # Read creation date from metadata if available
            created=""
            [[ -f "${dir}.sudosoc/meta" ]] && created=$(grep '^created=' "${dir}.sudosoc/meta" 2>/dev/null | cut -d= -f2-)
            echo -e "  🟢 \e[32m$(basename "$dir")\e[0m  \e[90mPy ${py_ver}  |  ${pkg_count} pkgs${created:+  |  created: ${created}}\e[0m"
            found=1
        fi
    done
    shopt -u nullglob
    [[ $found -eq 0 ]] && echo -e "  \e[33mNo global environments found.\e[0m"
    exit 0
fi

# =============================================================================
# SECTION 7: --delete
# Searches current directory and SUDOSOC_HOME for the target env
# =============================================================================
if [[ "$ACTION" == "delete" ]]; then
    TARGET=""
    [[ -f "${ENV_NAME}/bin/activate" ]] && TARGET="${ENV_NAME}"
    [[ -z "$TARGET" && -f "${SUDOSOC_HOME_DIR}/${ENV_NAME}/bin/activate" ]] && TARGET="${SUDOSOC_HOME_DIR}/${ENV_NAME}"

    if [[ -z "$TARGET" ]]; then
        echo -e "\e[31m❌ '${ENV_NAME}' is not a valid virtual environment.\e[0m" >&2
        echo -e "\e[33m💡 Check --list or --global-list.\e[0m"
        exit 1
    fi

    if [[ $CONFIRM_DELETE -eq 0 ]]; then
        echo -e "\e[33m⚠️  About to permanently delete: '${TARGET}'\e[0m"
        read -rp "  Are you sure? [y/N] " _confirm
        [[ ! "$_confirm" =~ ^[Yy]$ ]] && { echo -e "\e[34mℹ️  Cancelled.\e[0m"; exit 0; }
    fi

    rm -rf "$TARGET"
    log_history "delete" "$ENV_NAME"
    echo -e "\e[32m🗑️  Deleted '${ENV_NAME}' successfully.\e[0m"
    exit 0
fi

# =============================================================================
# SECTION 8: Validate Name & Resolve Paths
# =============================================================================
if [[ -z "$ENV_NAME" ]]; then
    echo -e "\e[31m❌ No environment name provided.\e[0m" >&2
    echo -e "\e[33m💡 Usage: sudosoc-env <ENV_NAME>   |   sudosoc-env --help\e[0m"
    exit 1
fi

# Only allow safe characters to prevent injection into the rc-file
if [[ "$ENV_NAME" =~ [^a-zA-Z0-9_.\-] ]]; then
    echo -e "\e[31m❌ Invalid name '${ENV_NAME}'. Use: letters, numbers, -, _, .\e[0m" >&2
    exit 1
fi

# Resolve base directory
if [[ $USE_LOCAL -eq 1 ]]; then
    BASE_DIR="$(pwd)"
elif [[ $USE_HOME -eq 1 || -n "${SUDOSOC_HOME:-}" ]]; then
    BASE_DIR="$SUDOSOC_HOME_DIR"
    mkdir -p "$BASE_DIR"
else
    BASE_DIR="$(pwd)"
fi

FULL_PATH="${BASE_DIR}/${ENV_NAME}"

# =============================================================================
# SECTION 9: --activate only
# Search current dir first, then SUDOSOC_HOME
# =============================================================================
if [[ $ACTIVATE_ONLY -eq 1 ]]; then
    if [[ -f "${FULL_PATH}/bin/activate" ]]; then
        : # found in expected location
    elif [[ -f "${SUDOSOC_HOME_DIR}/${ENV_NAME}/bin/activate" ]]; then
        FULL_PATH="${SUDOSOC_HOME_DIR}/${ENV_NAME}"
    else
        echo -e "\e[31m❌ Environment '${ENV_NAME}' not found.\e[0m" >&2
        echo -e "\e[33m💡 Run --list or --global-list to see available environments.\e[0m"
        exit 1
    fi
    echo -e "\e[34mℹ️  Activating '${ENV_NAME}'...\e[0m"
fi

# =============================================================================
# SECTION 10: pyenv Fallback
# If the requested Python is not in PATH, try to find it via pyenv
# =============================================================================
resolve_python() {
    command -v "$PYTHON_CMD" &>/dev/null && return 0

    local PYENV_ROOT_DIR="${PYENV_ROOT:-${HOME}/.pyenv}"
    if [[ ! -d "$PYENV_ROOT_DIR" ]]; then return 1; fi

    # e.g. PYTHON_CMD="python3.11" → ver_hint="3.11"
    local ver_hint="${PYTHON_CMD#python}"
    local match
    match=$(find "${PYENV_ROOT_DIR}/versions" -maxdepth 2 -name "python${ver_hint}" 2>/dev/null | head -1)

    if [[ -n "$match" ]]; then
        PYTHON_CMD="$match"
        echo -e "\e[90m🐍 Using pyenv: ${PYTHON_CMD}\e[0m"
        return 0
    fi
    return 1
}

# =============================================================================
# SECTION 11: Create or Locate Environment
# =============================================================================
if [[ $ACTIVATE_ONLY -eq 0 ]]; then
    if [[ -d "$FULL_PATH" && -f "$FULL_PATH/bin/activate" ]]; then
        echo -e "\e[34mℹ️  Environment '${ENV_NAME}' already exists. Entering...\e[0m"
    else
        echo -e "\e[36m⚙️  Creating '${ENV_NAME}' with ${PYTHON_CMD}...\e[0m"

        if ! resolve_python; then
            echo -e "\e[31m❌ Python '${PYTHON_CMD}' not found (checked PATH + pyenv).\e[0m" >&2
            exit 1
        fi

        VENV_FLAGS=()
        [[ $NO_SYSTEM_PKGS -eq 0 ]] && VENV_FLAGS+=("--system-site-packages")

        if ! "$PYTHON_CMD" -m venv "${VENV_FLAGS[@]}" "$FULL_PATH"; then
            echo -e "\e[31m❌ venv creation failed. Is python3-venv installed?\e[0m" >&2
            [[ -d "$FULL_PATH" ]] && rm -rf "$FULL_PATH"
            exit 1
        fi

        # Standard housekeeping
        echo "*" > "$FULL_PATH/.gitignore"
        mkdir -p "$FULL_PATH/.sudosoc"

        # Save creation metadata (read by sudosoc-info and --global-list)
        {
            echo "created=$(date '+%Y-%m-%d %H:%M:%S')"
            echo "python=${PYTHON_CMD}"
            echo "version=${VERSION}"
        } > "$FULL_PATH/.sudosoc/meta"

        do_lazy_pip_upgrade
        log_history "create" "$ENV_NAME"
        run_hook "on_create" "$FULL_PATH"

        echo -e "\e[32m✅ Environment '${ENV_NAME}' created successfully.\e[0m"
    fi
fi

# =============================================================================
# SECTION 12: Resolve PS1 Theme
# Builds the prompt string before injecting it into the rc-file
# =============================================================================
case "$THEME" in
    minimal)
        PS1_STRING="(${ENV_NAME}) \u:\w\$ " ;;
    neon)
        PS1_STRING='\[\e[1;95m\](sudosoc:'"${ENV_NAME}"')\[\e[0m\] \[\e[1;93m\]\u\[\e[0m\]:\[\e[1;92m\]\w\[\e[0m\]\$ ' ;;
    pastel)
        PS1_STRING='\[\e[38;5;183m\](sudosoc:'"${ENV_NAME}"')\[\e[0m\] \[\e[38;5;157m\]\u\[\e[0m\]:\[\e[38;5;153m\]\w\[\e[0m\]\$ ' ;;
    *)  # classic (default)
        PS1_STRING='\[\e[1;36m\](sudosoc:'"${ENV_NAME}"')\[\e[0m\] \[\e[1;32m\]\u\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ ' ;;
esac

# =============================================================================
# SECTION 13: Build RC File
#
# Strategy: use a function that writes to stdout (redirected to temp file).
#   - Build-time values (ENV_NAME, paths) are written as variable assignments
#     via echo, so they expand NOW and are embedded as literals.
#   - Runtime function bodies are written via a single-quoted heredoc
#     (FUNCTIONS_EOF), which prevents any expansion during rc-file construction.
#     Variables like $VIRTUAL_ENV, $@, $1, etc. are safe inside it.
# =============================================================================
echo -e "\e[32m🚀 Entering environment '${ENV_NAME}'...\e[0m"
USER_SHELL=$(basename "$SHELL")

build_rc() {
    # ── Source the user's existing shell config ──────────────────────────────
    if [[ "$USER_SHELL" == "zsh" ]]; then
        echo 'source "$HOME/.zshrc" 2>/dev/null'
    else
        echo 'source "$HOME/.bashrc" 2>/dev/null'
    fi
    echo ""

    # ── Embed build-time context as shell variables ───────────────────────────
    # These are read by internal commands at runtime (e.g. sudosoc-note uses
    # SUDOSOC_ENV_PATH, sudosoc-clone uses SUDOSOC_HOME_DIR)
    echo "# === Sudosoc-Env: runtime context ==="
    echo "SUDOSOC_ENV_NAME='${ENV_NAME}'"
    echo "SUDOSOC_ENV_PATH='${FULL_PATH}'"
    echo "SUDOSOC_HOME_DIR='${SUDOSOC_HOME_DIR}'"
    echo "SUDOSOC_VERSION='${VERSION}'"
    echo "SUDOSOC_VERSION_PIN='${VERSION_PIN}'"
    echo ""

    # ── Activate the virtual environment ─────────────────────────────────────
    echo "source '${FULL_PATH}/bin/activate'"
    echo ""

    # ── Custom PS1 (bash only — zsh handles venv prompt natively) ────────────
    if [[ "$USER_SHELL" == "bash" ]]; then
        echo "export PS1='${PS1_STRING}'"
        echo ""
    fi

    # ── on_activate hook (if present) ────────────────────────────────────────
    if [[ -f "${FULL_PATH}/.sudosoc/on_activate.sh" && -x "${FULL_PATH}/.sudosoc/on_activate.sh" ]]; then
        echo "echo -e '\\e[90m🪝 Running hook: on_activate.sh\\e[0m'"
        echo "bash '${FULL_PATH}/.sudosoc/on_activate.sh'"
        echo ""
    fi

    # ── Auto-install requirements.txt if -r was passed ───────────────────────
    if [[ $INSTALL_REQ -eq 1 ]]; then
        cat << 'INSTALL_REQ_BLOCK'
if [[ -f requirements.txt ]]; then
    echo -e '\e[33m📦 Installing requirements.txt...\e[0m'
    pip install -r requirements.txt
else
    echo -e '\e[31m⚠️  requirements.txt not found in current directory.\e[0m'
fi
INSTALL_REQ_BLOCK
        echo ""
    fi

    # =========================================================================
    # Internal command definitions
    # Single-quoted heredoc: nothing expands here. Runtime variables
    # ($VIRTUAL_ENV, $@, $1, $SUDOSOC_ENV_NAME, etc.) are safe.
    # =========================================================================
    cat << 'FUNCTIONS_EOF'

# ── sudosoc-exit ──────────────────────────────────────────────────────────────
# Runs on_exit hook, deactivates, and exits the subshell
sudosoc-exit() {
    if [[ -f "${SUDOSOC_ENV_PATH}/.sudosoc/on_exit.sh" && -x "${SUDOSOC_ENV_PATH}/.sudosoc/on_exit.sh" ]]; then
        echo -e "\e[90m🪝 Running hook: on_exit.sh\e[0m"
        bash "${SUDOSOC_ENV_PATH}/.sudosoc/on_exit.sh"
    fi
    deactivate 2>/dev/null
    echo -e "\e[33m👋 Exited '${SUDOSOC_ENV_NAME}'.\e[0m"
    exit
}

# ── sudosoc-save ──────────────────────────────────────────────────────────────
# Freezes local packages; also writes .lock if --version-pin was passed
sudosoc-save() {
    pip freeze --local > requirements.txt \
        && echo -e "\e[32m💾 Saved to requirements.txt\e[0m" \
        || { echo -e "\e[31m❌ Save failed.\e[0m"; return 1; }
    [[ "$SUDOSOC_VERSION_PIN" == "1" ]] && sudosoc-lock
}

# ── sudosoc-lock ──────────────────────────────────────────────────────────────
# Generates requirements.lock with exact pinned versions
sudosoc-lock() {
    pip freeze --local > requirements.lock \
        && echo -e "\e[32m🔒 requirements.lock created (exact pins).\e[0m" \
        || echo -e "\e[31m❌ Lock failed.\e[0m"
}

# ── sudosoc-reset ─────────────────────────────────────────────────────────────
# Uninstalls all locally-installed packages safely
sudosoc-reset() {
    echo -e "\e[33m🧹 Resetting environment...\e[0m"
    local _pkgs; _pkgs=$(pip freeze --local 2>/dev/null)
    if [[ -z "$_pkgs" ]]; then
        echo -e "\e[34mℹ️  Nothing to uninstall.\e[0m"
    else
        echo "$_pkgs" | xargs pip uninstall -y \
            && echo -e "\e[32m♻️  Reset complete.\e[0m"
    fi
}

# ── sudosoc-update ────────────────────────────────────────────────────────────
# Upgrades all outdated local packages in one shot
sudosoc-update() {
    echo -e "\e[33m🔄 Checking for outdated packages...\e[0m"
    local _outdated; _outdated=$(pip list --local --outdated --format=freeze 2>/dev/null | cut -d= -f1)
    if [[ -z "$_outdated" ]]; then
        echo -e "\e[32m✅ Everything is up to date!\e[0m"
    else
        echo "$_outdated" | xargs pip install --upgrade \
            && echo -e "\e[32m✅ Update complete.\e[0m"
    fi
}

# ── sudosoc-add ───────────────────────────────────────────────────────────────
# Installs one or more packages and immediately saves to requirements.txt
sudosoc-add() {
    if [[ $# -eq 0 ]]; then
        echo -e "\e[31m❌ Usage: sudosoc-add <package> [package2...]\e[0m"
        return 1
    fi
    pip install "$@" && pip freeze --local > requirements.txt \
        && echo -e "\e[32m📦 Installed and saved to requirements.txt.\e[0m"
}

# ── sudosoc-run ───────────────────────────────────────────────────────────────
# Auto-detects the project entry point and runs it
sudosoc-run() {
    if   [[ -f main.py   ]]; then echo -e "\e[36m▶️  Running main.py...\e[0m";        python main.py
    elif [[ -f app.py    ]]; then echo -e "\e[36m▶️  Running app.py...\e[0m";         python app.py
    elif [[ -f manage.py ]]; then echo -e "\e[36m▶️  Running Django server...\e[0m";  python manage.py runserver
    else echo -e "\e[31m❌ No entry point found (main.py / app.py / manage.py).\e[0m"
    fi
}

# ── sudosoc-info ──────────────────────────────────────────────────────────────
# Shows a summary of the current environment
sudosoc-info() {
    echo -e "\e[36m╔══════════════════════════════════╗\e[0m"
    echo -e "\e[36m║      📊  Environment Info        ║\e[0m"
    echo -e "\e[36m╚══════════════════════════════════╝\e[0m"
    echo -e " 🐍  Python   : $(python --version 2>&1)"
    echo -e " 📦  Packages : $(pip freeze --local 2>/dev/null | wc -l | tr -d ' ') local"
    echo -e " 💾  Size     : $(du -sh "$VIRTUAL_ENV" 2>/dev/null | cut -f1)"
    echo -e " 📁  Path     : $VIRTUAL_ENV"
    if [[ -f "${SUDOSOC_ENV_PATH}/.sudosoc/meta" ]]; then
        local _created; _created=$(grep '^created=' "${SUDOSOC_ENV_PATH}/.sudosoc/meta" | cut -d= -f2-)
        echo -e " 📅  Created  : ${_created}"
    fi
}

# ── sudosoc-check ─────────────────────────────────────────────────────────────
# Lists outdated packages without upgrading them
sudosoc-check() {
    echo -e "\e[33m🔍 Outdated packages in '${SUDOSOC_ENV_NAME}':\e[0m"
    pip list --local --outdated
}

# ── sudosoc-clone ─────────────────────────────────────────────────────────────
# Clones the current environment (packages included) into a new one
sudosoc-clone() {
    if [[ $# -eq 0 ]]; then
        echo -e "\e[31m❌ Usage: sudosoc-clone <new-env-name>\e[0m"; return 1
    fi
    local new_name="$1"
    if [[ "$new_name" =~ [^a-zA-Z0-9_.\-] ]]; then
        echo -e "\e[31m❌ Invalid name. Use letters, numbers, -, _, .\e[0m"; return 1
    fi
    local new_path="${SUDOSOC_HOME_DIR}/${new_name}"
    if [[ -d "$new_path" ]]; then
        echo -e "\e[31m❌ '${new_name}' already exists in SUDOSOC_HOME.\e[0m"; return 1
    fi

    echo -e "\e[36m⚙️  Cloning '${SUDOSOC_ENV_NAME}' → '${new_name}'...\e[0m"
    mkdir -p "${SUDOSOC_HOME_DIR}"
    python -m venv "$new_path"

    # Copy current package list to the clone
    local _tmp_req; _tmp_req=$(mktemp /tmp/sudosoc_clone_XXXXXX.txt)
    pip freeze --local > "$_tmp_req"
    if [[ -s "$_tmp_req" ]]; then
        echo -e "\e[33m📦 Transferring packages...\e[0m"
        "${new_path}/bin/pip" install --quiet -r "$_tmp_req"
    fi
    rm -f "$_tmp_req"

    echo "*" > "${new_path}/.gitignore"
    mkdir -p "${new_path}/.sudosoc"
    echo -e "\e[32m✅ Cloned to '${new_path}'.\e[0m"
    echo -e "\e[33m💡 Enter with: sudosoc-env --home -a ${new_name}\e[0m"
}

# ── sudosoc-doctor ────────────────────────────────────────────────────────────
# Runs a health check on the current environment
sudosoc-doctor() {
    local _ok="\e[32m✅\e[0m" _warn="\e[33m⚠️ \e[0m" _fail="\e[31m❌\e[0m"
    echo -e "\e[36m╔══════════════════════════════════╗\e[0m"
    echo -e "\e[36m║     🩺  Environment Doctor       ║\e[0m"
    echo -e "\e[36m╚══════════════════════════════════╝\e[0m"

    # Python executable
    python --version &>/dev/null \
        && echo -e " ${_ok} Python    : $(python --version 2>&1)" \
        || echo -e " ${_fail} Python    : not responding"

    # pip executable
    pip --version &>/dev/null \
        && echo -e " ${_ok} pip       : $(pip --version | awk '{print $1,$2}')" \
        || echo -e " ${_fail} pip       : not found"

    # activate script integrity
    [[ -f "$VIRTUAL_ENV/bin/activate" ]] \
        && echo -e " ${_ok} Activate  : present" \
        || echo -e " ${_fail} Activate  : missing (env may be corrupted)"

    # requirements.txt sync check
    if [[ -f requirements.txt ]]; then
        local _frozen; _frozen=$(pip freeze --local 2>/dev/null)
        if [[ "$_frozen" == "$(cat requirements.txt)" ]]; then
            echo -e " ${_ok} req.txt   : in sync"
        else
            echo -e " ${_warn} req.txt   : out of sync (run sudosoc-save)"
        fi
    else
        echo -e " ${_warn} req.txt   : not found"
    fi

    # Disk size
    local _sz; _sz=$(du -sh "$VIRTUAL_ENV" 2>/dev/null | cut -f1)
    echo -e " ${_ok} Size      : ${_sz}"

    # Outdated package count
    local _n; _n=$(pip list --local --outdated 2>/dev/null | tail -n +3 | wc -l | tr -d ' ')
    if [[ "$_n" == "0" ]]; then
        echo -e " ${_ok} Packages  : all up to date"
    else
        echo -e " ${_warn} Packages  : ${_n} outdated (run sudosoc-update)"
    fi
}

# ── sudosoc-search ────────────────────────────────────────────────────────────
# Searches PyPI using its JSON API — no browser needed
sudosoc-search() {
    if [[ $# -eq 0 ]]; then
        echo -e "\e[31m❌ Usage: sudosoc-search <package>\e[0m"; return 1
    fi
    local pkg="$1"
    echo -e "\e[33m🔍 Searching PyPI for '${pkg}'...\e[0m"
    local result; result=$(curl -sf --max-time 6 "https://pypi.org/pypi/${pkg}/json" 2>/dev/null)
    if [[ -z "$result" ]] || ! echo "$result" | grep -q '"info"'; then
        echo -e "\e[31m  '${pkg}' not found on PyPI.\e[0m"
        echo -e "\e[33m  💡 Tip: pip install ${pkg}\e[0m"
        return 1
    fi
    # Parse and display using Python (result passed via env var to avoid pipe/heredoc conflict)
    PYPI_JSON="$result" python3 << 'SEARCH_PY'
import os, json
d = json.loads(os.environ['PYPI_JSON'])
i = d['info']
releases = sorted(d.get('releases', {}).keys(), reverse=True)[:5]
name    = i.get('name', '-')
ver     = i.get('version', '-')
summary = (i.get('summary') or '-')[:72]
author  = i.get('author') or '-'
lic     = i.get('license') or '-'
url     = i.get('project_url') or i.get('home_page') or '-'
print(f"\033[32m  {name}\033[0m  v{ver}")
print(f"  {summary}")
print(f"  Author  : {author}")
print(f"  License : {lic}")
print(f"  URL     : {url}")
print(f"  Recent  : {' | '.join(releases)}")
SEARCH_PY
}

# ── sudosoc-note ──────────────────────────────────────────────────────────────
# View or add timestamped notes attached to this environment
sudosoc-note() {
    local _note_file="${SUDOSOC_ENV_PATH}/.sudosoc/notes.md"
    mkdir -p "${SUDOSOC_ENV_PATH}/.sudosoc"
    if [[ $# -eq 0 ]]; then
        if [[ -f "$_note_file" ]]; then
            echo -e "\e[36m📝 Notes for '${SUDOSOC_ENV_NAME}':\e[0m"
            cat "$_note_file"
        else
            echo -e "\e[33mNo notes yet. Add one: sudosoc-note <your note>\e[0m"
        fi
    else
        echo "$(date '+%Y-%m-%d %H:%M') — $*" >> "$_note_file"
        echo -e "\e[32m📝 Note saved.\e[0m"
    fi
}

# ── sudosoc-docker ────────────────────────────────────────────────────────────
# Generates a production-ready Dockerfile based on the current environment
sudosoc-docker() {
    local _py_ver; _py_ver=$(python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    local _req="requirements.txt"
    [[ -f "requirements.lock" ]] && _req="requirements.lock"
    local _entry="main.py"
    [[ -f "app.py"    ]] && _entry="app.py"
    [[ -f "manage.py" ]] && _entry="manage.py"

    if [[ -f "Dockerfile" ]]; then
        echo -e "\e[33m⚠️  Dockerfile already exists. Overwrite? [y/N]\e[0m"
        read -r _ow; [[ ! "$_ow" =~ ^[Yy]$ ]] && { echo "Cancelled."; return 0; }
    fi

    cat > Dockerfile << DOCKERFILE_HEREDOC
# Generated by Sudosoc-Env Pro v${SUDOSOC_VERSION}  (env: ${SUDOSOC_ENV_NAME})
FROM python:${_py_ver}-slim

WORKDIR /app

# Install dependencies first (layer cache-friendly)
COPY ${_req} .
RUN pip install --no-cache-dir -r ${_req}

# Copy project files
COPY . .

EXPOSE 8000
CMD ["python", "${_entry}"]
DOCKERFILE_HEREDOC

    echo -e "\e[32m🐳 Dockerfile generated:\e[0m"
    echo -e "   Base  : python:${_py_ver}-slim"
    echo -e "   Reqs  : ${_req}"
    echo -e "   Entry : ${_entry}"
    echo -e "\e[33m💡 Build : docker build -t ${SUDOSOC_ENV_NAME} .\e[0m"
    echo -e "\e[33m💡 Run   : docker run --rm ${SUDOSOC_ENV_NAME}\e[0m"
}

# ── sudosoc-bench ─────────────────────────────────────────────────────────────
# Runs a lightweight Python micro-benchmark inside the environment
sudosoc-bench() {
    echo -e "\e[36m╔══════════════════════════════════╗\e[0m"
    echo -e "\e[36m║    ⚡  Python Micro-Benchmark    ║\e[0m"
    echo -e "\e[36m╚══════════════════════════════════╝\e[0m"
    python3 << 'BENCH_PY'
import timeit, sys, platform

tests = [
    ("Integer sum       ", "sum(range(10_000))",                        5_000),
    ("List comprehension", "[x**2 for x in range(1_000)]",              5_000),
    ("Dict creation     ", "{i: i**2 for i in range(500)}",             5_000),
    ("String multiply   ", "'x' * 10_000",                             10_000),
    ("Fibonacci(20)     ", "(lambda f: f(f,20))(lambda f,n: n if n<2 else f(f,n-1)+f(f,n-2))", 1_000),
]

print(f"  Python {sys.version.split()[0]}  |  {platform.machine()}")
print()
for label, stmt, n in tests:
    t = timeit.timeit(stmt, number=n)
    ms = t * 1000
    bar = "█" * min(int(ms / 4) + 1, 22)
    print(f"  {label}  {ms:7.1f}ms  {bar}")
BENCH_PY
}

# ── Welcome banner (runs once on shell entry) ─────────────────────────────────
echo -e '\e[35m╔══════════════════════════════════════════════╗\e[0m'
echo -e "\e[35m║  ✨  Sudosoc-Env  |  env: ${SUDOSOC_ENV_NAME}\e[0m"
echo -e '\e[35m╚══════════════════════════════════════════════╝\e[0m'
echo -e '\e[90m  sudosoc-exit  exit  |  sudosoc-info  stats  |  sudosoc-run  start\e[0m'
echo -e '\e[90m  sudosoc-doctor  health  |  sudosoc-bench  speed  |  sudosoc-docker  🐳\e[0m'
echo ""

FUNCTIONS_EOF
}

# =============================================================================
# SECTION 14: Launch Child Shell
# Writes the rc file, registers a cleanup trap, then launches the shell
# =============================================================================
log_history "activate" "$ENV_NAME"

if [[ "$USER_SHELL" == "zsh" ]]; then
    TMP_ZDOTDIR=$(mktemp -d)
    trap 'rm -rf "$TMP_ZDOTDIR"' EXIT
    build_rc > "$TMP_ZDOTDIR/.zshrc"
    ZDOTDIR="$TMP_ZDOTDIR" zsh -i

elif [[ "$USER_SHELL" == "fish" ]]; then
    # Fish: limited support — only activates, no internal commands
    echo -e "\e[33m⚠️  Fish shell detected — basic activation only.\e[0m"
    fish -C "source '${FULL_PATH}/bin/activate.fish'"

else
    # Bash (default)
    TMP_BASHRC=$(mktemp)
    trap 'rm -f "$TMP_BASHRC"' EXIT
    build_rc > "$TMP_BASHRC"
    bash --rcfile "$TMP_BASHRC" -i
fi
