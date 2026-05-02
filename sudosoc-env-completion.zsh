#compdef sudosoc-env
# =============================================================================
# Sudosoc-Env Pro — Zsh Tab Completion
# Install: add this line to your ~/.zshrc:
#   source /path/to/sudosoc-env-completion.zsh
# Or place in a directory on your $fpath and run: compinit
# =============================================================================

_sudosoc_env() {
    local context state state_descr line
    typeset -A opt_args

    _arguments -C \
        '(-h --help)'{-h,--help}'[Show help menu]' \
        '(-v --version)'{-v,--version}'[Show version number]' \
        '(-l --list)'{-l,--list}'[List envs in current directory]' \
        '--global-list[List all envs in SUDOSOC_HOME]' \
        '(-d --delete)'{-d,--delete}'[Delete an environment]:environment:_sudosoc_env_names' \
        '(-r --requirements)'{-r,--requirements}'[Install requirements.txt on entry]' \
        '(-p --python)'{-p,--python}'[Python interpreter]:python:_sudosoc_python_versions' \
        '(-a --activate)'{-a,--activate}'[Activate an existing environment]:environment:_sudosoc_env_names' \
        '--force[Skip delete confirmation]' \
        '--no-system-pkgs[Isolate from system site-packages]' \
        '--version-pin[Also write requirements.lock on save]' \
        '--home[Create/find environment in SUDOSOC_HOME]' \
        '--local[Force current directory]' \
        '--theme[PS1 color theme]:theme:(classic minimal neon pastel)' \
        '1:environment name:_sudosoc_env_names'
}

# Collect environment names from both current directory and SUDOSOC_HOME
_sudosoc_env_names() {
    local -a envs
    local dir

    # From current directory
    local dirs=(*/)
    for dir in "${dirs[@]}"; do
        [[ -f "${dir}bin/activate" ]] && envs+=("${dir%/}")
    done

    # From SUDOSOC_HOME
    local _home="${SUDOSOC_HOME:-${HOME}/.sudosoc_envs}"
    if [[ -d "$_home" ]]; then
        local gdirs=("${_home}"/*/); local gdir
        for gdir in "${gdirs[@]}"; do
            [[ -f "${gdir}bin/activate" ]] && envs+=("$(basename "$gdir")")
        done
    fi

    compadd -a envs
}

# Suggest available Python interpreters found in PATH
_sudosoc_python_versions() {
    local -a pyvers
    pyvers=( ${(f)"$(compgen -c 2>/dev/null | grep -E '^python[0-9]' | sort -u)"} )
    compadd -a pyvers
}

_sudosoc_env "$@"
