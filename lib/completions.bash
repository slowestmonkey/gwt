# ─────────────────────────────────────────────────────────────────────────────
# Bash Completions
# Note: Works best with bash-completion package installed (provides _init_completion)
# On macOS: brew install bash-completion@2
# On Linux: usually pre-installed, or: apt install bash-completion
# ─────────────────────────────────────────────────────────────────────────────

_gwt_complete_branches() {
  local branches=()
  while IFS= read -r line; do
    [[ "$line" == branch* ]] && branches+=("${line#branch refs/heads/}")
  done <<< "$(git worktree list --porcelain 2>/dev/null)"
  echo "${branches[*]}"
}

_gwt_complete_git_branches() {
  git branch -a --format='%(refname:short)' 2>/dev/null
}

_gwt_complete_providers() {
  echo "${!GWT_PROVIDERS[*]}"
}

_gwt_completions() {
  local cur prev words cword
  _init_completion 2>/dev/null || {
    # Fallback if _init_completion not available
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    words=("${COMP_WORDS[@]}")
    cword=$COMP_CWORD
  }

  local commands="create list ls switch remove rm clean config help"
  local create_opts="-h --help -l --local -d --dangerous -s --safe -b"
  local switch_opts="-h --help -n --no-ai -d --dangerous -s --safe"
  local remove_opts="-h --help -f --force -k --keep-branch"
  local clean_opts="-h --help -f --force"
  local config_subcmds="provider edit set"
  local help_topics="create list switch remove clean config"

  # Handle first argument (command)
  if [[ $cword -eq 1 ]]; then
    COMPREPLY=($(compgen -W "$commands -h --help -v --version --debug" -- "$cur"))
    return
  fi

  # Handle --debug as first arg
  if [[ "${words[1]}" == "--debug" ]]; then
    if [[ $cword -eq 2 ]]; then
      COMPREPLY=($(compgen -W "$commands" -- "$cur"))
      return
    fi
    # Shift effective command position
    local cmd="${words[2]}"
    local effective_cword=$((cword - 1))
  else
    local cmd="${words[1]}"
    local effective_cword=$cword
  fi

  case "$cmd" in
    create)
      case "$prev" in
        -b)
          local branches
          branches=$(_gwt_complete_git_branches)
          COMPREPLY=($(compgen -W "$branches" -- "$cur"))
          ;;
        *)
          if [[ "$cur" == -* ]]; then
            COMPREPLY=($(compgen -W "$create_opts" -- "$cur"))
          fi
          ;;
      esac
      ;;

    switch)
      if [[ "$cur" == -* ]]; then
        COMPREPLY=($(compgen -W "$switch_opts" -- "$cur"))
      else
        local branches
        branches=$(_gwt_complete_branches)
        COMPREPLY=($(compgen -W "$branches" -- "$cur"))
      fi
      ;;

    remove|rm)
      if [[ "$cur" == -* ]]; then
        COMPREPLY=($(compgen -W "$remove_opts" -- "$cur"))
      else
        local branches
        branches=$(_gwt_complete_branches)
        COMPREPLY=($(compgen -W "$branches" -- "$cur"))
      fi
      ;;

    clean)
      COMPREPLY=($(compgen -W "$clean_opts" -- "$cur"))
      ;;

    config)
      case "$effective_cword" in
        2)
          COMPREPLY=($(compgen -W "$config_subcmds" -- "$cur"))
          ;;
        3)
          case "$prev" in
            provider)
              local providers
              providers=$(_gwt_complete_providers)
              COMPREPLY=($(compgen -W "$providers" -- "$cur"))
              ;;
            set)
              COMPREPLY=($(compgen -W "GWT_PROVIDER GWT_DEBUG" -- "$cur"))
              ;;
          esac
          ;;
      esac
      ;;

    help)
      COMPREPLY=($(compgen -W "$help_topics" -- "$cur"))
      ;;

    list|ls)
      COMPREPLY=($(compgen -W "-h --help" -- "$cur"))
      ;;
  esac
}

_gwt_register_completions() {
  # Only register if running in bash
  if [[ -n "$BASH_VERSION" ]]; then
    complete -F _gwt_completions gwt
  fi
}
