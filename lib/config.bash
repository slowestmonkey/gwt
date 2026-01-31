# ─────────────────────────────────────────────────────────────────────────────
# Configuration Management (Bash version)
# ─────────────────────────────────────────────────────────────────────────────

# Version
GWT_VERSION="2.0.0"

# Config file locations (in order of priority)
GWT_CONFIG_PATHS=(
  "./.gwt.conf"
  "$HOME/.config/gwt/config"
  "$HOME/.gwt.conf"
)

# Session tracking directory
GWT_SESSION_DIR="$HOME/.gwt-worktrees/.sessions"

# Debug mode (set GWT_DEBUG=1 to enable)
: "${GWT_DEBUG:=0}"

# Default provider (can be overridden via config or GWT_PROVIDER env var)
: "${GWT_PROVIDER:=claude}"

# Debug logging
_gwt_debug() {
  [[ "$GWT_DEBUG" == "1" ]] && echo "[gwt:debug] $*" >&2
}

# Load user config if exists
_gwt_load_config() {
  local config_file
  for config_file in "${GWT_CONFIG_PATHS[@]}"; do
    if [[ -f "$config_file" ]]; then
      _gwt_debug "Loading config from: $config_file"
      source "$config_file"
      return 0
    fi
  done
  _gwt_debug "No config file found"
  return 1
}

# Check if provider was explicitly configured
_gwt_provider_configured() {
  # Check if config file exists and contains GWT_PROVIDER
  local config_file
  for config_file in "${GWT_CONFIG_PATHS[@]}"; do
    if [[ -f "$config_file" ]] && grep -q "^GWT_PROVIDER=" "$config_file" 2>/dev/null; then
      return 0
    fi
  done
  # Check if env var was set before sourcing
  [[ -n "${GWT_PROVIDER_SET:-}" ]] && return 0
  return 1
}

# Validate configuration
_gwt_validate_config() {
  if [[ -n "$GWT_PROVIDER" ]] && [[ -z "${GWT_PROVIDERS[$GWT_PROVIDER]:-}" ]]; then
    echo "gwt: unknown provider '$GWT_PROVIDER' in config" >&2
    echo "gwt: available providers: ${!GWT_PROVIDERS[*]}" >&2
    return 1
  fi
  return 0
}

# Save config value
_gwt_save_config() {
  local key="$1" value="$2"
  local config_file="$HOME/.config/gwt/config"

  mkdir -p "$(dirname "$config_file")"

  if [[ -f "$config_file" ]]; then
    # Update existing key or append
    if grep -q "^${key}=" "$config_file" 2>/dev/null; then
      # Use temp file for portability
      local tmp
      tmp=$(mktemp)
      sed "s/^${key}=.*/${key}=${value}/" "$config_file" > "$tmp"
      mv "$tmp" "$config_file"
    else
      echo "${key}=${value}" >> "$config_file"
    fi
  else
    echo "${key}=${value}" > "$config_file"
  fi
  _gwt_debug "Saved $key=$value to $config_file"
}

# Show current config
_gwt_show_config() {
  echo -e "\033[1mGWT Configuration\033[0m\n"

  # Show active config file
  local config_file found=false
  for config_file in "${GWT_CONFIG_PATHS[@]}"; do
    if [[ -f "$config_file" ]]; then
      echo -e "Config file: \033[32m$config_file\033[0m"
      found=true
      break
    fi
  done
  $found || echo -e "Config file: \033[33m(none)\033[0m"

  echo ""
  echo "Settings:"
  echo "  GWT_PROVIDER=$GWT_PROVIDER"
  echo "  GWT_DEBUG=$GWT_DEBUG"
  echo ""
  echo "Storage: $HOME/.gwt-worktrees/"
  echo "Sessions: $GWT_SESSION_DIR"
}
