#!/bin/bash
# =============================================================================
# Sudosoc-Env Pro — Bash Tab Completion
# Install: add this line to your ~/.bashrc:
#   source /path/to/sudosoc-env-completion.bash
# =============================================================================

_sudosoc_env_complete() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # All available flags
    opts="-h --help -v --version -l --list --global-list \
          -d --delete -r --requirements -p --python \
          -a --activate --force --no-system-pkgs \
          --version-pin --home --local --theme"

    case "$prev" in
        # Complete with environment names for these flags
        -a|--activate|-d|--delete)
            local envs=""
            # Scan current directory
            local dir
            shopt -s nullglob
            for dir in */; do
                [[ -f "${dir}bin/activate" ]] && envs+=" ${dir%/}"
            done
            shopt -u nullglob
            # Scan SUDOSOC_HOME
            local _home="${SUDOSOC_HOME:-${HOME}/.sudosoc_envs}"
            if [[ -d "$_home" ]]; then
                shopt -s nullglob
                for dir in "${_home}/*/"; do
                    [[ -f "${dir}bin/activate" ]] && envs+=" $(basename "$dir")"
                done
                shopt -u nullglob
            fi
            COMPREPLY=( $(compgen -W "$envs" -- "$cur") )
            return 0 ;;

        # Complete theme names
        --theme)
            COMPREPLY=( $(compgen -W "classic minimal neon pastel" -- "$cur") )
            return 0 ;;

        # Complete available Python versions
        -p|--python)
            local pyvers
            pyvers=$(compgen -c | grep -E '^python[0-9]' | sort -u)
            COMPREPLY=( $(compgen -W "$pyvers" -- "$cur") )
            return 0 ;;
    esac

    # Complete flags if current word starts with -
    if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "$opts" -- "$cur") )
        return 0
    fi

    # Otherwise complete with directory names (potential new env names)
    COMPREPLY=( $(compgen -d -- "$cur") )
}

complete -F _sudosoc_env_complete sudosoc-env
