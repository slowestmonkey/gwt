# Git Worktree Management Functions
# Worktrees are stored in ~/.claude-worktrees/{repo-name}/{worktree-name}

# Helper: Check if in git repo
_gwt_require_repo() {
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "Error: Not inside a git repository" >&2
    return 1
  fi
}

# Helper: Get default branch (main or master)
_gwt_default_branch() {
  git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main"
}

# Helper: Show help for all commands
_gwt_help() {
  cat <<'EOF'
gwt-claude - Git worktree manager for parallel Claude Code sessions

Commands:
  gwt-create [-l | -b <branch>] <name>   Create worktree + open Claude Code
    -l, --local    Create from current branch (default: main)
    -b <branch>    Create from specific branch

  gwt-list                               List all worktrees

  gwt-switch <branch>                    Switch to worktree by branch name

  gwt-remove [-f] <branch>               Remove worktree by branch name
    -f, --force    Skip confirmation + remove dirty worktrees

Worktrees are stored in: ~/.claude-worktrees/{repo}/{name}
EOF
}

# Helper: Find worktree path by branch name
# Usage: _gwt_find_path <branch>
# Returns: path via stdout, or empty + error message if not found
_gwt_find_path() {
  local search_branch="$1"
  local wt_path="" found_paths=()

  # Parse porcelain output: worktree, HEAD, branch lines
  local current_path="" current_branch=""
  while IFS= read -r line; do
    if [[ "$line" == worktree* ]]; then
      current_path="${line#worktree }"
    elif [[ "$line" == branch* ]]; then
      current_branch="${line#branch refs/heads/}"
      # Check for exact match
      if [[ "$current_branch" == "$search_branch" ]]; then
        found_paths+=("$current_path")
      # Check for partial match (e.g., "feature" matches "feat/feature-xyz")
      elif [[ "$current_branch" == *"$search_branch"* ]]; then
        found_paths+=("$current_path")
      fi
    fi
  done < <(git worktree list --porcelain)

  # Not found
  if [[ ${#found_paths[@]} -eq 0 ]]; then
    echo "Error: No worktree found with branch matching '$search_branch'" >&2
    echo "" >&2
    echo "Available worktrees:" >&2
    gwt-list >&2
    return 1
  fi

  # Multiple matches
  if [[ ${#found_paths[@]} -gt 1 ]]; then
    echo "Error: Multiple worktrees match '$search_branch':" >&2
    for p in "${found_paths[@]}"; do
      echo "  $p" >&2
    done
    echo "" >&2
    echo "Please be more specific." >&2
    return 1
  fi

  echo "${found_paths[1]}"
}

# Usage: gwt-create [-l | -b <branch>] <name>
# Default: creates from default branch. Use -l for current branch, -b for specific branch.
gwt-create() {
  _gwt_require_repo || return 1

  local base_branch="" wt_name="" use_local=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) _gwt_help; return 0 ;;
      -l|--local) use_local=true; shift ;;
      -b) base_branch="$2"; shift 2 ;;
      *)  wt_name="$1"; shift ;;
    esac
  done

  if [[ -z "$wt_name" ]]; then
    echo "Usage: gwt-create [-l | -b <branch>] <name>" >&2
    echo "       -l    Create from current branch (default: $(_gwt_default_branch))" >&2
    echo "       -b    Create from specific branch" >&2
    return 1
  fi

  # Determine base branch
  if [[ "$use_local" == true ]]; then
    base_branch=$(git branch --show-current)
  elif [[ -z "$base_branch" ]]; then
    base_branch=$(_gwt_default_branch)
  fi

  # Check if branch is already checked out in another worktree
  if git worktree list | grep -q "\[$wt_name\]"; then
    echo "Error: Branch '$wt_name' is already checked out in another worktree:" >&2
    git worktree list | grep "\[$wt_name\]" >&2
    return 1
  fi

  # Get original repo name (first worktree is always the main repo)
  local repo_root=$(git worktree list --porcelain | head -1 | sed 's/^worktree //')
  local repo_name=$(basename "$repo_root")
  local dir_name="${wt_name//\//-}"
  local worktree_base="$HOME/.claude-worktrees/${repo_name}"
  local worktree_path="${worktree_base}/${dir_name}"

  mkdir -p "$worktree_base"

  if [[ -d "$worktree_path" ]]; then
    echo "Worktree already exists at: $worktree_path"
    echo "Opening Claude Code..."
    cd "$worktree_path" && claude
    return 0
  fi

  echo "Creating worktree at: $worktree_path (from $base_branch)"
  if git show-ref --verify --quiet "refs/heads/$wt_name"; then
    git worktree add "$worktree_path" "$wt_name"
  else
    git worktree add -b "$wt_name" "$worktree_path" "$base_branch"
  fi

  if [[ $? -eq 0 ]]; then
    echo "Opening Claude Code in worktree..."
    cd "$worktree_path" && claude
  else
    echo "Error: Failed to create worktree" >&2
    return 1
  fi
}

# Usage: gwt-list
gwt-list() {
  [[ "$1" == "-h" || "$1" == "--help" ]] && { _gwt_help; return 0; }
  _gwt_require_repo || return 1

  local current_dir=$(pwd)
  echo "\033[1mGit Worktrees:\033[0m"
  echo ""

  local wt_path head_line branch_line branch
  git worktree list --porcelain | while read line; do
    if [[ "$line" == worktree* ]]; then
      wt_path="${line#worktree }"
      read head_line  # HEAD <sha>
      read branch_line  # branch refs/heads/... or detached

      if [[ "$branch_line" == branch* ]]; then
        branch="${branch_line#branch refs/heads/}"
      else
        branch="(detached)"
      fi

      if [[ "$current_dir" == "$wt_path"* ]]; then
        echo "  \033[32m→ $branch\033[0m"
        echo "    $wt_path"
      else
        echo "  \033[34m$branch\033[0m"
        echo "    $wt_path"
      fi
      echo ""
    fi
  done
}

# Usage: gwt-remove [-f] <branch>
gwt-remove() {
  _gwt_require_repo || return 1

  local force=false search_branch=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) _gwt_help; return 0 ;;
      -f|--force) force=true; shift ;;
      *)          search_branch="$1"; shift ;;
    esac
  done

  if [[ -z "$search_branch" ]]; then
    echo "Usage: gwt-remove [-f] <branch>" >&2
    echo "       -f    Force remove (skip confirmation + dirty worktrees)" >&2
    echo "" >&2
    echo "Available worktrees:" >&2
    gwt-list
    return 1
  fi

  local worktree_path=$(_gwt_find_path "$search_branch") || return 1

  # Prevent removing main repository
  local main_repo=$(git worktree list --porcelain | head -1 | sed 's/^worktree //')
  if [[ "$worktree_path" == "$main_repo" ]]; then
    echo "Error: Cannot remove main repository" >&2
    return 1
  fi

  # Prevent removing current worktree
  if [[ "$(pwd)" == "$worktree_path"* ]]; then
    echo "Error: Cannot remove current worktree. Switch to another first." >&2
    return 1
  fi

  # Check for uncommitted changes
  if [[ -n $(git -C "$worktree_path" status --porcelain 2>/dev/null) ]]; then
    echo "Warning: Worktree has uncommitted changes" >&2
    if [[ "$force" != true ]]; then
      echo "Use -f to force removal" >&2
      return 1
    fi
  fi

  if [[ "$force" != true ]]; then
    echo "Remove worktree at: $worktree_path? [y/N]"
    read -r response
    [[ ! "$response" =~ ^[Yy]$ ]] && echo "Cancelled" && return 0
  fi

  if git worktree remove --force "$worktree_path"; then
    echo "Worktree removed: $worktree_path"
    git worktree prune
  else
    echo "Error: Failed to remove worktree" >&2
    return 1
  fi
}

# Usage: gwt-switch <branch>
gwt-switch() {
  _gwt_require_repo || return 1

  local search_branch=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) _gwt_help; return 0 ;;
      *)         search_branch="$1"; shift ;;
    esac
  done

  if [[ -z "$search_branch" ]]; then
    echo "Usage: gwt-switch <branch>" >&2
    echo "" >&2
    echo "Available worktrees:" >&2
    gwt-list
    return 1
  fi

  local worktree_path=$(_gwt_find_path "$search_branch") || return 1

  cd "$worktree_path"
  echo "Switched to: $worktree_path"
}
