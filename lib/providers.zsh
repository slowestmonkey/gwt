# ─────────────────────────────────────────────────────────────────────────────
# Provider Registry & Management
# ─────────────────────────────────────────────────────────────────────────────

# Provider registry: command|safe_flags|dangerous_flags|display_name
typeset -gA GWT_PROVIDERS
GWT_PROVIDERS=(
  [claude]="claude|--allowedTools|--dangerously-skip-permissions|Claude Code"
  [opencode]="opencode|||OpenCode"
  [aider]="aider|||Aider"
  [cursor]="cursor|||Cursor"
)

# Claude-specific allowed tools for safe mode
GWT_ALLOWED_TOOLS=(
  "Read" "Edit" "Write" "Grep" "Glob"
  "Bash(git:*)" "Bash(npm:*)" "Bash(ls:*)" "Bash(cat:*)"
)

# Load custom providers from providers.d/
_gwt_load_custom_providers() {
  local provider_dir="${GWT_SCRIPT_DIR}/providers.d"
  if [[ -d "$provider_dir" ]]; then
    for f in "$provider_dir"/*.zsh(N); do
      _gwt_debug "Loading custom provider: $f"
      source "$f"
    done
  fi
  
  # Also load from user config dir
  local user_provider_dir="$HOME/.config/gwt/providers.d"
  if [[ -d "$user_provider_dir" ]]; then
    for f in "$user_provider_dir"/*.zsh(N); do
      _gwt_debug "Loading user provider: $f"
      source "$f"
    done
  fi
}

# Get provider info: returns "command|safe_flags|dangerous_flags|display_name"
_gwt_get_provider() {
  local provider="${1:-$GWT_PROVIDER}"
  echo "${GWT_PROVIDERS[$provider]:-}"
}

# Check if provider is available (command exists)
_gwt_provider_available() {
  local provider="${1:-$GWT_PROVIDER}"
  local info=$(_gwt_get_provider "$provider")
  [[ -z "$info" ]] && return 1
  local cmd="${info%%|*}"
  command -v "$cmd" &>/dev/null
}

# List available providers
_gwt_list_providers() {
  echo "Available providers:"
  local provider info cmd name available
  for provider in ${(k)GWT_PROVIDERS}; do
    info="${GWT_PROVIDERS[$provider]}"
    cmd="${info%%|*}"
    name="${info##*|}"
    if command -v "$cmd" &>/dev/null; then
      available="\033[32m✓\033[0m"
    else
      available="\033[31m✗\033[0m"
    fi
    [[ "$provider" == "$GWT_PROVIDER" ]] && name="$name \033[33m(active)\033[0m"
    echo "  $available $provider - $name"
  done
}

# Interactive provider selection (with recursion guard)
_gwt_select_provider() {
  local _gwt_select_depth=${_gwt_select_depth:-0}
  
  if (( _gwt_select_depth > 3 )); then
    echo "gwt: too many provider selection attempts" >&2
    return 1
  fi
  
  local available=() provider info cmd name
  
  # Build list of available (installed) providers (in preferred order)
  for provider in claude opencode aider cursor; do
    info="${GWT_PROVIDERS[$provider]:-}"
    [[ -z "$info" ]] && continue
    cmd="${info%%|*}"
    name="${info##*|}"
    command -v "$cmd" &>/dev/null && available+=("$provider:$name")
  done
  
  # Also check custom providers
  for provider in ${(k)GWT_PROVIDERS}; do
    [[ "$provider" =~ ^(claude|opencode|aider|cursor)$ ]] && continue
    info="${GWT_PROVIDERS[$provider]}"
    cmd="${info%%|*}"
    name="${info##*|}"
    command -v "$cmd" &>/dev/null && available+=("$provider:$name")
  done
  
  [[ ${#available[@]} -eq 0 ]] && {
    echo "gwt: no AI coding assistants found" >&2
    echo "gwt: install one of: claude, opencode, aider, cursor" >&2
    return 1
  }
  
  # If only one available, use it
  [[ ${#available[@]} -eq 1 ]] && {
    GWT_PROVIDER="${available[1]%%:*}"
    echo "Auto-selected provider: ${available[1]#*:} (only one installed)"
    return 0
  }
  
  # Interactive selection
  echo "\033[1mSelect your AI coding assistant:\033[0m\n"
  local i=1
  for item in "${available[@]}"; do
    local p="${item%%:*}"
    local n="${item#*:}"
    echo "  $i) $n ($p)"
    ((i++))
  done
  echo ""
  
  local choice
  while true; do
    echo -n "Enter choice [1-${#available[@]}]: "
    read -r choice
    [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#available[@]} )) && break
    echo "Invalid choice. Try again."
  done
  
  GWT_PROVIDER="${available[$choice]%%:*}"
  local selected_name="${available[$choice]#*:}"
  echo ""
  echo "Selected: $selected_name"
  
  # Offer to save
  echo -n "Save to config (~/.config/gwt/config)? [Y/n]: "
  read -r save_choice
  [[ ! "$save_choice" =~ ^[Nn]$ ]] && {
    _gwt_save_config "GWT_PROVIDER" "$GWT_PROVIDER"
    echo "Saved! You won't be asked again."
  }
  echo ""
}

# Launch the configured provider (with recursion guard)
_gwt_launch_provider() {
  local mode="${1:-default}"
  local _gwt_launch_depth=${_gwt_launch_depth:-0}
  
  if (( _gwt_launch_depth > 3 )); then
    echo "gwt: too many provider launch attempts" >&2
    return 1
  fi
  
  # Interactive selection if not configured
  if ! _gwt_provider_configured; then
    _gwt_select_provider || return 1
  fi
  
  local provider="${GWT_PROVIDER}"
  local info=$(_gwt_get_provider "$provider")
  
  # Check if provider exists in registry
  if [[ -z "$info" ]]; then
    echo "gwt: unknown provider '$provider'" >&2
    echo "gwt: set GWT_PROVIDER or add provider to config" >&2
    _gwt_list_providers >&2
    return 1
  fi
  
  # Parse provider info: command|safe_flags|dangerous_flags|display_name
  local cmd safe_flags dangerous_flags display_name
  cmd="${info%%|*}"
  info="${info#*|}"
  safe_flags="${info%%|*}"
  info="${info#*|}"
  dangerous_flags="${info%%|*}"
  display_name="${info#*|}"
  
  # Check if command exists
  if ! command -v "$cmd" &>/dev/null; then
    echo "gwt: '$cmd' not found. Install $display_name first." >&2
    echo ""
    echo -n "Select a different provider? [Y/n]: "
    read -r choice
    [[ "$choice" =~ ^[Nn]$ ]] && return 1
    (( _gwt_launch_depth++ ))
    _gwt_select_provider || return 1
    _gwt_launch_provider "$mode"
    return $?
  fi
  
  _gwt_debug "Launching $display_name in $mode mode"
  echo "Opening $display_name..."
  
  # Track session
  _gwt_session_start "$$" "$provider"
  
  local exit_code=0
  case "$mode" in
    dangerous)
      if [[ -n "$dangerous_flags" ]]; then
        $cmd $dangerous_flags || exit_code=$?
      else
        echo "Warning: $display_name doesn't support dangerous mode, using default" >&2
        $cmd || exit_code=$?
      fi
      ;;
    safe)
      if [[ -n "$safe_flags" ]]; then
        # Claude-specific: safe mode uses --allowedTools with tool list
        if [[ "$provider" == "claude" ]]; then
          $cmd $safe_flags "${GWT_ALLOWED_TOOLS[@]}" || exit_code=$?
        else
          $cmd $safe_flags || exit_code=$?
        fi
      else
        echo "Warning: $display_name doesn't support safe mode, using default" >&2
        $cmd || exit_code=$?
      fi
      ;;
    *)
      $cmd || exit_code=$?
      ;;
  esac
  
  # Clear session
  _gwt_session_end
  
  # Handle failed launch
  if [[ $exit_code -ne 0 ]]; then
    echo ""
    echo "gwt: $display_name exited with code $exit_code" >&2
    echo -n "Select a different provider? [Y/n]: "
    read -r choice
    [[ "$choice" =~ ^[Nn]$ ]] && return $exit_code
    (( _gwt_launch_depth++ ))
    _gwt_select_provider || return 1
    _gwt_launch_provider "$mode"
    return $?
  fi
}
