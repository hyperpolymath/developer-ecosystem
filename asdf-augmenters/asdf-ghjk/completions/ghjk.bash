# Bash completion for asdf ghjk commands
# Source this file or add to ~/.bashrc:
# source /path/to/asdf-ghjk/completions/ghjk.bash

_asdf_ghjk_completion() {
  local cur prev words cword
  _init_completion || return

  # asdf ghjk specific completions
  case "${words[2]}" in
    install)
      if [[ "${cword}" -eq 3 ]]; then
        # Complete with available versions
        local versions
        versions=$(asdf list all ghjk 2>/dev/null | tr ' ' '\n')
        COMPREPLY=( $(compgen -W "${versions} latest" -- "${cur}") )
      fi
      ;;
    uninstall)
      if [[ "${cword}" -eq 3 ]]; then
        # Complete with installed versions
        local versions
        versions=$(asdf list ghjk 2>/dev/null)
        COMPREPLY=( $(compgen -W "${versions}" -- "${cur}") )
      fi
      ;;
    global|local|shell)
      if [[ "${cword}" -eq 3 ]]; then
        # Complete with installed versions
        local versions
        versions=$(asdf list ghjk 2>/dev/null)
        COMPREPLY=( $(compgen -W "${versions} latest system" -- "${cur}") )
      fi
      ;;
  esac
}

# Register completion
complete -F _asdf_ghjk_completion asdf
