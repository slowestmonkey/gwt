# ─────────────────────────────────────────────────────────────────────────────
# Public Commands (Bash version)
# ─────────────────────────────────────────────────────────────────────────────

# ═══════════════════════════════════════════════════════════════════════════════
# gwt create - Create a new worktree and launch AI assistant
# ═══════════════════════════════════════════════════════════════════════════════
_gwt_cmd_create() {
  [[ "$1" == "-h" || "$1" == "--help" ]] && { _gwt_help_create; return 0; }
  _gwt_require_repo || return 1

  # Parse arguments
  local base="" name="" local_branch=false mode="default"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)      _gwt_help_create; return 0 ;;
      -l|--local)     local_branch=true; shift ;;
      -d|--dangerous) mode="dangerous"; shift ;;
      -s|--safe)      mode="safe"; shift ;;
      -b)
        [[ -z "$2" ]] && { echo "gwt: -b requires a branch name" >&2; return 1; }
        base="$2"; shift 2
        ;;
      -*)             echo "gwt: unknown option '$1'" >&2; return 1 ;;
      *)              name="$1"; shift ;;
    esac
  done

  [[ -z "$name" ]] && {
    echo "gwt: missing branch name" >&2
    echo "Usage: gwt create [-l | -b <branch>] [-s|-d] <name>" >&2
    return 1
  }

  # Determine base branch
  if $local_branch; then
    base=$(_gwt_current_branch)
    if [[ -z "$base" ]]; then
      echo "gwt: cannot use -l/--local in detached HEAD state" >&2
      echo "gwt: use -b <branch> to specify a base branch instead" >&2
      return 1
    fi
  elif [[ -z "$base" ]]; then
    base=$(_gwt_default_branch)
  fi

  _gwt_debug "Creating worktree '$name' from base '$base'"

  # Check if already checked out
  if git worktree list | grep -q "\[$name\]"; then
    echo "gwt: branch '$name' already checked out in another worktree" >&2
    return 1
  fi

  local wt_path
  wt_path=$(_gwt_worktree_path "$name")
  mkdir -p "$(dirname "$wt_path")"

  # Reuse existing worktree
  if [[ -d "$wt_path" ]]; then
    echo "Worktree exists: $wt_path"
    cd "$wt_path" || { echo "gwt: failed to enter worktree" >&2; return 1; }
    _gwt_launch_provider "$mode"
    return $?
  fi

  # Create worktree
  echo "Creating: $wt_path (from $base)"
  if git show-ref --verify --quiet "refs/heads/$name"; then
    git worktree add "$wt_path" "$name"
  else
    git worktree add -b "$name" "$wt_path" "$base"
  fi || { echo "gwt: failed to create worktree" >&2; return 1; }

  cd "$wt_path" || { echo "gwt: failed to enter worktree" >&2; return 1; }

  # Optional: install dependencies
  [[ -f "package.json" ]] && {
    echo -n "Found package.json. Install dependencies? [y/N]: "
    read -r response
    [[ "$response" =~ ^[Yy]$ ]] && npm install
  }

  # Optional: copy .env files
  local main_repo
  main_repo=$(_gwt_main_repo)
  local env_files=()
  # Bash equivalent of ${(@f)$(find ...)}
  while IFS= read -r -d '' f; do
    env_files+=("$f")
  done < <(find "$main_repo" -maxdepth 3 -name ".env*" -type f -print0 2>/dev/null)

  if [[ ${#env_files[@]} -gt 0 && -n "${env_files[0]}" ]]; then
    echo -n "Found ${#env_files[@]} .env file(s). Copy? [y/N]: "
    read -r response
    [[ "$response" =~ ^[Yy]$ ]] && {
      for env_file in "${env_files[@]}"; do
        local rel_path="${env_file#$main_repo/}"
        local target_dir
        target_dir="$(dirname "$rel_path")"
        [[ "$target_dir" != "." ]] && mkdir -p "$target_dir"
        cp "$env_file" "$rel_path"
      done
      echo "Copied ${#env_files[@]} .env file(s)"
    }
  fi

  _gwt_launch_provider "$mode"
}

# ═══════════════════════════════════════════════════════════════════════════════
# gwt list - List all worktrees with status
# ═══════════════════════════════════════════════════════════════════════════════
_gwt_cmd_list() {
  [[ "$1" == "-h" || "$1" == "--help" ]] && { _gwt_help_list; return 0; }
  _gwt_require_repo || return 1

  _gwt_session_cleanup

  local cwd
  cwd=$(_gwt_realpath "$(pwd)")
  echo -e "\033[1mGit Worktrees:\033[0m\n"

  local wt_path="" wt_branch="" head_line="" branch_line=""
  while IFS= read -r line; do
    if [[ "$line" == worktree* ]]; then
      wt_path="${line#worktree }"
      read -r head_line
      read -r branch_line
      if [[ "$branch_line" == branch* ]]; then
        wt_branch="${branch_line#branch refs/heads/}"
      else
        wt_branch="(detached)"
      fi

      local indicator="" status_text="" session_indicator=""
      local resolved_wt
      resolved_wt=$(_gwt_realpath "$wt_path")
      [[ "$cwd" == "$resolved_wt"* ]] && indicator="→ "

      _gwt_session_active "$wt_path" && session_indicator=$' \033[35m⚡\033[0m'

      if [[ -n "$(git -C "$wt_path" status --porcelain 2>/dev/null)" ]]; then
        status_text=$'\033[33m●\033[0m dirty'
      else
        status_text=$'\033[32m●\033[0m clean'
      fi

      if git -C "$wt_path" rev-parse --abbrev-ref '@{upstream}' &>/dev/null; then
        local ahead behind
        ahead=$(git -C "$wt_path" rev-list --count '@{upstream}..HEAD' 2>/dev/null)
        behind=$(git -C "$wt_path" rev-list --count 'HEAD..@{upstream}' 2>/dev/null)
        [[ "$ahead" -gt 0 ]] && status_text="$status_text ↑$ahead"
        [[ "$behind" -gt 0 ]] && status_text="$status_text ↓$behind"
      fi

      if [[ -n "$indicator" ]]; then
        echo -e "  \033[32m$indicator$wt_branch\033[0m$session_indicator  $status_text"
      else
        echo -e "  \033[34m$wt_branch\033[0m$session_indicator  $status_text"
      fi
      echo -e "    $wt_path\n"
    fi
  done <<< "$(git worktree list --porcelain)"
}

# ═══════════════════════════════════════════════════════════════════════════════
# gwt switch - Switch to existing worktree (optionally launch AI)
# ═══════════════════════════════════════════════════════════════════════════════
_gwt_cmd_switch() {
  [[ "$1" == "-h" || "$1" == "--help" ]] && { _gwt_help_switch; return 0; }
  _gwt_require_repo || return 1

  local wt_branch="" mode="default" no_ai=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)      _gwt_help_switch; return 0 ;;
      -n|--no-ai)     no_ai=true; shift ;;
      -d|--dangerous) mode="dangerous"; shift ;;
      -s|--safe)      mode="safe"; shift ;;
      -*)             echo "gwt: unknown option '$1'" >&2; return 1 ;;
      *)              wt_branch="$1"; shift ;;
    esac
  done

  [[ -z "$wt_branch" ]] && {
    echo "gwt: missing branch name" >&2
    echo ""
    _gwt_cmd_list
    return 1
  }

  local wt_path
  wt_path=$(_gwt_find_path "$wt_branch") || return 1
  cd "$wt_path" || { echo "gwt: failed to enter worktree at $wt_path" >&2; return 1; }
  echo "Switched to: $wt_path"

  $no_ai || _gwt_launch_provider "$mode"
}

# ═══════════════════════════════════════════════════════════════════════════════
# gwt clean - Remove all clean worktrees
# ═══════════════════════════════════════════════════════════════════════════════
_gwt_cmd_clean() {
  [[ "$1" == "-h" || "$1" == "--help" ]] && { _gwt_help_clean; return 0; }
  _gwt_require_repo || return 1

  local force=false
  [[ "$1" == "-f" || "$1" == "--force" ]] && force=true

  local main_repo
  main_repo=$(_gwt_main_repo)
  local cwd
  cwd=$(_gwt_realpath "$(pwd)")
  local to_remove=()
  local wt_path="" wt_branch=""

  while IFS= read -r line; do
    if [[ "$line" == worktree* ]]; then
      wt_path="${line#worktree }"
      read -r _
      read -r branch_line
      if [[ "$branch_line" == branch* ]]; then
        wt_branch="${branch_line#branch refs/heads/}"
      else
        wt_branch=""
      fi

      [[ "$wt_path" == "$main_repo" ]] && continue
      [[ "$(_gwt_realpath "$wt_path")" == "$cwd"* ]] && continue
      [[ -n "$wt_branch" ]] && _gwt_is_protected "$wt_branch" && continue

      if [[ -z "$(git -C "$wt_path" status --porcelain 2>/dev/null)" ]]; then
        to_remove+=("$wt_path:$wt_branch")
      fi
    fi
  done <<< "$(git worktree list --porcelain)"

  if [[ ${#to_remove[@]} -eq 0 ]]; then
    echo "No clean worktrees to remove"
    return 0
  fi

  echo "Clean worktrees to remove:"
  for item in "${to_remove[@]}"; do
    echo "  - ${item#*:} (${item%%:*})"
  done
  echo ""

  if ! $force; then
    echo -n "Remove all ${#to_remove[@]} worktrees? [y/N]: "
    read -r response
    [[ ! "$response" =~ ^[Yy]$ ]] && { echo "Cancelled"; return 0; }
  fi

  local removed=0
  for item in "${to_remove[@]}"; do
    local wt_rm_path="${item%%:*}"
    local wt_rm_branch="${item#*:}"

    if git worktree remove --force "$wt_rm_path" 2>/dev/null; then
      echo "Removed: $wt_rm_path"
      ((removed++))
      if [[ -n "$wt_rm_branch" ]] && ! _gwt_is_protected "$wt_rm_branch"; then
        git branch -D "$wt_rm_branch" 2>/dev/null && echo "Deleted branch: $wt_rm_branch"
      fi
    fi
  done

  git worktree prune
  echo -e "\nRemoved $removed worktree(s)"
}

# ═══════════════════════════════════════════════════════════════════════════════
# gwt remove - Remove worktree and branch
# ═══════════════════════════════════════════════════════════════════════════════
_gwt_cmd_remove() {
  [[ "$1" == "-h" || "$1" == "--help" ]] && { _gwt_help_remove; return 0; }
  _gwt_require_repo || return 1

  local force=false keep_branch=false wt_branch=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)        _gwt_help_remove; return 0 ;;
      -f|--force)       force=true; shift ;;
      -k|--keep-branch) keep_branch=true; shift ;;
      -*)               echo "gwt: unknown option '$1'" >&2; return 1 ;;
      *)                wt_branch="$1"; shift ;;
    esac
  done

  [[ -z "$wt_branch" ]] && {
    echo "gwt: missing branch name" >&2
    _gwt_cmd_list
    return 1
  }

  _gwt_is_protected "$wt_branch" && {
    echo "gwt: cannot remove protected branch '$wt_branch'" >&2
    return 1
  }

  local wt_path
  wt_path=$(_gwt_find_path "$wt_branch") || return 1
  local main
  main=$(_gwt_main_repo)
  local cwd
  cwd=$(_gwt_realpath "$(pwd)")
  local resolved_wt
  resolved_wt=$(_gwt_realpath "$wt_path")

  [[ "$resolved_wt" == "$(_gwt_realpath "$main")" ]] && {
    echo "gwt: cannot remove main repository" >&2
    return 1
  }

  [[ "$cwd" == "$resolved_wt"* ]] && {
    echo "gwt: cannot remove current worktree. Switch first." >&2
    return 1
  }

  local branch_to_delete=""
  while IFS= read -r line; do
    [[ "$line" == worktree* ]] && local wt="${line#worktree }"
    [[ "$line" == branch* ]] && {
      local br="${line#branch refs/heads/}"
      [[ "$wt" == "$wt_path" ]] && branch_to_delete="$br"
    }
  done <<< "$(git worktree list --porcelain)"

  if [[ -n $(git -C "$wt_path" status --porcelain 2>/dev/null) ]] && ! $force; then
    echo "gwt: worktree has uncommitted changes. Use -f to force." >&2
    return 1
  fi

  if ! $force; then
    echo -n "Remove $wt_path? [y/N]: "
    read -r response
    [[ ! "$response" =~ ^[Yy]$ ]] && { echo "Cancelled"; return 0; }
  fi

  git worktree remove --force "$wt_path" || {
    echo "gwt: failed to remove worktree" >&2
    return 1
  }
  echo "Removed: $wt_path"
  git worktree prune

  if ! $keep_branch && [[ -n "$branch_to_delete" ]] && ! _gwt_is_protected "$branch_to_delete"; then
    git branch -D "$branch_to_delete" 2>/dev/null && echo "Deleted local branch: $branch_to_delete"

    git fetch --prune origin 2>/dev/null
    if git show-ref --verify --quiet "refs/remotes/origin/$branch_to_delete"; then
      echo -n "Delete remote 'origin/$branch_to_delete'? [y/N]: "
      read -r response
      [[ "$response" =~ ^[Yy]$ ]] && \
        git push origin --delete "$branch_to_delete" 2>/dev/null && \
        echo "Deleted remote branch"
    fi
  fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# gwt config - Show/edit configuration and manage providers
# ═══════════════════════════════════════════════════════════════════════════════
_gwt_cmd_config() {
  [[ "$1" == "-h" || "$1" == "--help" ]] && { _gwt_help_config; return 0; }

  case "$1" in
    "")
      _gwt_show_config
      echo ""
      _gwt_list_providers
      ;;
    provider|providers)
      if [[ -n "$2" ]]; then
        # Set provider
        local provider="$2"
        local info="${GWT_PROVIDERS[$provider]:-}"

        if [[ -z "$info" ]]; then
          echo "gwt: unknown provider '$provider'" >&2
          echo "Available: ${!GWT_PROVIDERS[*]}" >&2
          return 1
        fi

        local cmd="${info%%|*}"
        local name="${info##*|}"

        if ! command -v "$cmd" &>/dev/null; then
          echo "gwt: '$cmd' not found. Install $name first." >&2
          return 1
        fi

        _gwt_save_config "GWT_PROVIDER" "$provider"
        export GWT_PROVIDER="$provider"
        echo "Provider set to: $name ($provider)"
      else
        # Interactive selection
        echo -e "\033[1mCurrent provider:\033[0m $GWT_PROVIDER\n"
        _gwt_list_providers
        echo ""
        echo -n "Select new provider? [y/N]: "
        read -r choice
        [[ "$choice" =~ ^[Yy]$ ]] && _gwt_select_provider
      fi
      ;;
    edit)
      local config_file="$HOME/.config/gwt/config"
      mkdir -p "$(dirname "$config_file")"
      [[ ! -f "$config_file" ]] && touch "$config_file"
      ${EDITOR:-vim} "$config_file"
      ;;
    set)
      [[ -z "$2" || -z "$3" ]] && {
        echo "Usage: gwt config set <key> <value>" >&2
        return 1
      }
      _gwt_save_config "$2" "$3"
      echo "Set $2=$3"
      ;;
    *)
      echo "gwt: unknown config command '$1'" >&2
      echo "Usage: gwt config [provider [name] | edit | set <key> <value>]" >&2
      return 1
      ;;
  esac
}
