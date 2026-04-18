#compdef asdf

# Zsh completion for asdf ghjk commands
# Add to your ~/.zshrc:
# fpath=(${ASDF_DIR}/completions/ghjk.zsh $fpath)
# autoload -Uz compinit && compinit

_asdf_ghjk_versions() {
  local versions
  versions=(${(f)"$(asdf list all ghjk 2>/dev/null | tr ' ' '\n')"})
  _describe 'version' versions
}

_asdf_ghjk_installed_versions() {
  local versions
  versions=(${(f)"$(asdf list ghjk 2>/dev/null)"})
  _describe 'installed version' versions
}

_asdf_ghjk() {
  local context state line
  typeset -A opt_args

  case "$words[3]" in
    install)
      _asdf_ghjk_versions
      ;;
    uninstall)
      _asdf_ghjk_installed_versions
      ;;
    global|local|shell)
      _asdf_ghjk_installed_versions
      ;;
  esac
}

_asdf_ghjk "$@"
