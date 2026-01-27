# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  gwt - Git Worktree Manager for AI Coding Assistants                      ║
# ║  https://github.com/slowestmonkey/gwt-claude                              ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Determine script location for loading modules
GWT_SCRIPT_DIR="${0:A:h}"

# Load modules
source "$GWT_SCRIPT_DIR/lib/config.zsh"
source "$GWT_SCRIPT_DIR/lib/session.zsh"
source "$GWT_SCRIPT_DIR/lib/providers.zsh"
source "$GWT_SCRIPT_DIR/lib/git.zsh"
source "$GWT_SCRIPT_DIR/lib/help.zsh"
source "$GWT_SCRIPT_DIR/lib/commands.zsh"
source "$GWT_SCRIPT_DIR/lib/completions.zsh"

# Load config and custom providers
_gwt_load_config 2>/dev/null
[[ -n "$GWT_PROVIDER" ]] && GWT_PROVIDER_SET=1
_gwt_load_custom_providers
_gwt_validate_config || true

# ─────────────────────────────────────────────────────────────────────────────
# Main Entry Point
# ─────────────────────────────────────────────────────────────────────────────

# Remove any existing alias to avoid conflicts
unalias gwt 2>/dev/null

gwt() {
  # Handle --debug first (can combine with other args)
  if [[ "$1" == "--debug" ]]; then
    export GWT_DEBUG=1
    shift
  fi
  
  local cmd="${1:-}"
  shift 2>/dev/null || true
  
  case "$cmd" in
    -h|--help)    _gwt_help; return 0 ;;
    -v|--version) echo "gwt version $GWT_VERSION"; return 0 ;;
    create)       _gwt_cmd_create "$@" ;;
    list|ls)      _gwt_cmd_list "$@" ;;
    switch)       _gwt_cmd_switch "$@" ;;
    remove|rm)    _gwt_cmd_remove "$@" ;;
    clean)        _gwt_cmd_clean "$@" ;;
    config)       _gwt_cmd_config "$@" ;;
    help)
      case "$1" in
        create)    _gwt_help_create ;;
        list|ls)   _gwt_help_list ;;
        switch)    _gwt_help_switch ;;
        remove|rm) _gwt_help_remove ;;
        clean)     _gwt_help_clean ;;
        config)    _gwt_help_config ;;
        "")        _gwt_help ;;
        *)         echo "gwt: unknown command '$1'" >&2; return 1 ;;
      esac
      ;;
    "") _gwt_help ;;
    *)  echo "gwt: unknown command '$cmd'. Run 'gwt help'" >&2; return 1 ;;
  esac
}

_gwt_register_completions
