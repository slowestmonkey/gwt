# ─────────────────────────────────────────────────────────────────────────────
# Git Helper Functions
# ─────────────────────────────────────────────────────────────────────────────

# Check if inside a git repo
_gwt_require_repo() {
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "gwt: not inside a git repository" >&2
    echo "gwt: run this command from within a git project" >&2
    return 1
  fi
}

# Get main repository path (bare repo or primary checkout)
_gwt_main_repo() {
  git worktree list --porcelain | head -1 | sed 's/^worktree //'
}

# Get default branch (from origin/HEAD or fallback to "main")
_gwt_default_branch() {
  git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main"
}

# Sanitize branch name for filesystem use
_gwt_sanitize_branch_name() {
  local name="$1"
  # Replace problematic characters with dashes
  # Handles: / : * ? " < > | \ space
  echo "${name//[\/\:\*\?\"\<\>\|\\ ]/-}"
}

# Generate unique worktree path (handles repo name collisions)
_gwt_worktree_path() {
  local branch_name="$1"
  local repo_path=$(_gwt_main_repo)
  local repo_name=$(basename "$repo_path")
  
  # Create short hash of repo path to avoid collisions
  local repo_hash
  if command -v md5 &>/dev/null; then
    repo_hash=$(echo "$repo_path" | md5 | cut -c1-8)
  elif command -v md5sum &>/dev/null; then
    repo_hash=$(echo "$repo_path" | md5sum | cut -c1-8)
  else
    # Fallback: use last 8 chars of path hash via cksum
    repo_hash=$(echo "$repo_path" | cksum | cut -d' ' -f1)
  fi
  
  local safe_branch=$(_gwt_sanitize_branch_name "$branch_name")
  echo "$HOME/.gwt-worktrees/${repo_name}-${repo_hash}/${safe_branch}"
}

# Resolve path safely (handles symlinks)
_gwt_realpath() {
  local path="$1"
  if command -v realpath &>/dev/null; then
    realpath "$path" 2>/dev/null || echo "$path"
  elif command -v grealpath &>/dev/null; then
    grealpath "$path" 2>/dev/null || echo "$path"
  else
    # Fallback for macOS without coreutils
    cd "$path" 2>/dev/null && pwd -P || echo "$path"
  fi
}

# Find worktree path by branch name (exact or partial match)
_gwt_find_path() {
  local search="$1"
  local exact="" partial=()
  local wt_path="" wt_branch=""

  while IFS= read -r line; do
    [[ "$line" == worktree* ]] && wt_path="${line#worktree }"
    [[ "$line" == branch* ]] && {
      wt_branch="${line#branch refs/heads/}"
      [[ "$wt_branch" == "$search" ]] && exact="$wt_path"
      [[ "$wt_branch" == *"$search"* && -z "$exact" ]] && partial+=("$wt_path:$wt_branch")
    }
  done <<< "$(git worktree list --porcelain)"

  if [[ -n "$exact" ]]; then
    echo "$exact"
    return 0
  fi

  case ${#partial[@]} in
    0)
      echo "gwt: no worktree matches '$search'" >&2
      echo "gwt: use 'gwt list' to see available worktrees" >&2
      return 1
      ;;
    1)
      echo "${partial[1]%%:*}"
      ;;
    *)
      echo "gwt: multiple worktrees match '$search':" >&2
      for p in "${partial[@]}"; do
        echo "  - ${p#*:}" >&2
      done
      echo "gwt: please be more specific" >&2
      return 1
      ;;
  esac
}

# Check if branch is protected (main/master/default)
_gwt_is_protected() {
  local branch="$1"
  local default=$(_gwt_default_branch)
  [[ "$branch" == "$default" || "$branch" == "main" || "$branch" == "master" ]]
}

# Get current branch (with detached HEAD handling)
_gwt_current_branch() {
  local branch=$(git branch --show-current 2>/dev/null)
  if [[ -z "$branch" ]]; then
    echo ""
    return 1
  fi
  echo "$branch"
}

# Check if in detached HEAD state
_gwt_is_detached() {
  [[ -z "$(git branch --show-current 2>/dev/null)" ]]
}

# Get worktree info for a path
_gwt_worktree_info() {
  local search_path="$1"
  search_path=$(_gwt_realpath "$search_path")
  
  local wt_path="" wt_branch="" wt_head=""
  while IFS= read -r line; do
    case "$line" in
      worktree*) wt_path="${line#worktree }" ;;
      HEAD*) wt_head="${line#HEAD }" ;;
      branch*) 
        wt_branch="${line#branch refs/heads/}"
        if [[ "$(_gwt_realpath "$wt_path")" == "$search_path" ]]; then
          echo "$wt_branch|$wt_head|$wt_path"
          return 0
        fi
        ;;
    esac
  done <<< "$(git worktree list --porcelain)"
  return 1
}
