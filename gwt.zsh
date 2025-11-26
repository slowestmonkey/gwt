# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  gwt-claude - Git Worktree Manager for Claude Code                        ║
# ║  Worktrees stored in: ~/.claude-worktrees/{repo}/{branch}                 ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# ─────────────────────────────────────────────────────────────────────────────
# Private Helpers
# ─────────────────────────────────────────────────────────────────────────────

_gwt_require_repo() {
  git rev-parse --is-inside-work-tree &>/dev/null || {
    echo "Error: Not inside a git repository" >&2
    return 1
  }
}

_gwt_main_repo() {
  git worktree list --porcelain | head -1 | sed 's/^worktree //'
}

_gwt_default_branch() {
  git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main"
}

_gwt_worktree_path() {
  local branch_name="$1"
  local repo_name=$(basename "$(_gwt_main_repo)")
  local dir_name="${branch_name//\//-}"
  echo "$HOME/.claude-worktrees/${repo_name}/${dir_name}"
}

_gwt_find_path() {
  local search="$1"
  local exact="" partial=()
  local porcelain=$(git worktree list --porcelain)
  local path="" branch=""

  while IFS= read -r line; do
    [[ "$line" == worktree* ]] && path="${line#worktree }"
    [[ "$line" == branch* ]] && {
      branch="${line#branch refs/heads/}"
      if [[ "$branch" == "$search" ]]; then
        exact="$path"
      elif [[ "$branch" == *"$search"* ]]; then
        partial+=("$path")
      fi
    }
  done <<< "$porcelain"

  # Prefer exact match
  [[ -n "$exact" ]] && { echo "$exact"; return 0; }

  case ${#partial[@]} in
    0) echo "Error: No worktree matches '$search'" >&2; return 1 ;;
    1) echo "${partial[1]}" ;;
    *) echo "Error: Multiple matches for '$search':" >&2
       printf '  %s\n' "${partial[@]}" >&2
       return 1 ;;
  esac
}

_gwt_help() {
  cat <<'EOF'
gwt-claude - Git worktree manager for parallel Claude Code sessions

COMMANDS
  gwt-create [-l|-b <branch>] [-d] <name>   Create worktree + open Claude Code
  gwt-list                                  List all worktrees
  gwt-switch [-d] <branch>                  Switch to worktree + open Claude Code
  gwt-remove [-f] [-k] <branch>             Remove worktree and branch

OPTIONS
  -l, --local        Create from current branch (default: main/master)
  -b <branch>        Create from specific branch
  -d, --dangerous    Run Claude with --dangerously-skip-permissions
  -f, --force        Skip confirmation, remove dirty worktrees
  -k, --keep-branch  Keep the branch when removing worktree
  -h, --help         Show this help

STORAGE
  ~/.claude-worktrees/{repo}/{branch}
EOF
}

# ─────────────────────────────────────────────────────────────────────────────
# Public Commands
# ─────────────────────────────────────────────────────────────────────────────

gwt-create() {
  _gwt_require_repo || return 1

  local base="" name="" local_branch=false dangerous=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)      _gwt_help; return 0 ;;
      -l|--local)     local_branch=true; shift ;;
      -d|--dangerous) dangerous=true; shift ;;
      -b)             base="$2"; shift 2 ;;
      *)              name="$1"; shift ;;
    esac
  done

  [[ -z "$name" ]] && {
    echo "Usage: gwt-create [-l | -b <branch>] <name>" >&2
    return 1
  }

  # Determine base branch
  if $local_branch; then
    base=$(git branch --show-current)
  elif [[ -z "$base" ]]; then
    base=$(_gwt_default_branch)
  fi

  # Check if already checked out
  git worktree list | grep -q "\[$name\]" && {
    echo "Error: Branch '$name' already checked out in another worktree" >&2
    return 1
  }

  local wt_path=$(_gwt_worktree_path "$name")
  mkdir -p "$(dirname "$wt_path")"

  # Reuse existing worktree
  [[ -d "$wt_path" ]] && {
    echo "Worktree exists: $wt_path"
    cd "$wt_path"
    $dangerous && claude --dangerously-skip-permissions || claude
    return 0
  }

  # Create worktree
  echo "Creating: $wt_path (from $base)"
  if git show-ref --verify --quiet "refs/heads/$name"; then
    git worktree add "$wt_path" "$name"
  else
    git worktree add -b "$name" "$wt_path" "$base"
  fi || { echo "Error: Failed to create worktree" >&2; return 1; }

  cd "$wt_path"

  # Optional: install dependencies
  [[ -f "package.json" ]] && {
    echo "Found package.json. Install dependencies? [y/N]"
    read -r response
    [[ "$response" =~ ^[Yy]$ ]] && npm install
  }

  echo "Opening Claude Code..."
  $dangerous && claude --dangerously-skip-permissions || claude
}

gwt-list() {
  [[ "$1" == "-h" || "$1" == "--help" ]] && { _gwt_help; return 0; }
  _gwt_require_repo || return 1

  local cwd=$(pwd)
  echo "\033[1mGit Worktrees:\033[0m\n"

  local porcelain=$(git worktree list --porcelain)
  local path="" branch="" head_line="" branch_line=""

  while IFS= read -r line; do
    if [[ "$line" == worktree* ]]; then
      path="${line#worktree }"
      read -r head_line
      read -r branch_line
      if [[ "$branch_line" == branch* ]]; then
        branch="${branch_line#branch refs/heads/}"
      else
        branch="(detached)"
      fi

      if [[ "$cwd" == "$path"* ]]; then
        echo "  \033[32m→ $branch\033[0m\n    $path\n"
      else
        echo "  \033[34m$branch\033[0m\n    $path\n"
      fi
    fi
  done <<< "$porcelain"
}

gwt-switch() {
  _gwt_require_repo || return 1

  local branch="" dangerous=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)      _gwt_help; return 0 ;;
      -d|--dangerous) dangerous=true; shift ;;
      *)              branch="$1"; shift ;;
    esac
  done

  [[ -z "$branch" ]] && {
    echo "Usage: gwt-switch <branch>" >&2
    gwt-list
    return 1
  }

  local wt_path=$(_gwt_find_path "$branch") || return 1
  cd "$wt_path"
  echo "Switched to: $wt_path"
  echo "Opening Claude Code..."
  $dangerous && claude --dangerously-skip-permissions || claude
}

gwt-remove() {
  _gwt_require_repo || return 1

  local force=false keep_branch=false branch=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)        _gwt_help; return 0 ;;
      -f|--force)       force=true; shift ;;
      -k|--keep-branch) keep_branch=true; shift ;;
      *)                branch="$1"; shift ;;
    esac
  done

  [[ -z "$branch" ]] && {
    echo "Usage: gwt-remove [-f] [-k] <branch>" >&2
    gwt-list
    return 1
  }

  local wt_path=$(_gwt_find_path "$branch") || return 1
  local main=$(_gwt_main_repo)

  # Safety checks
  [[ "$wt_path" == "$main" ]] && {
    echo "Error: Cannot remove main repository" >&2
    return 1
  }
  [[ "$(pwd)" == "$wt_path"* ]] && {
    echo "Error: Cannot remove current worktree. Switch first." >&2
    return 1
  }

  # Extract branch name before removal
  local branch_to_delete=""
  local porcelain=$(git worktree list --porcelain)
  local wt="" br=""
  while IFS= read -r line; do
    [[ "$line" == worktree* ]] && wt="${line#worktree }"
    [[ "$line" == branch* ]] && {
      br="${line#branch refs/heads/}"
      [[ "$wt" == "$wt_path" ]] && branch_to_delete="$br"
    }
  done <<< "$porcelain"

  # Dirty check
  [[ -n $(git -C "$wt_path" status --porcelain 2>/dev/null) ]] && ! $force && {
    echo "Warning: Uncommitted changes. Use -f to force." >&2
    return 1
  }

  # Confirmation
  ! $force && {
    echo "Remove $wt_path? [y/N]"
    read -r response
    [[ ! "$response" =~ ^[Yy]$ ]] && { echo "Cancelled"; return 0; }
  }

  git worktree remove --force "$wt_path" && {
    echo "Removed: $wt_path"
    git worktree prune

    # Delete branch unless -k flag or protected branch
    if ! $keep_branch && [[ -n "$branch_to_delete" ]]; then
      local default=$(_gwt_default_branch)
      if [[ "$branch_to_delete" != "$default" && "$branch_to_delete" != "main" && "$branch_to_delete" != "master" ]]; then
        git branch -D "$branch_to_delete" 2>/dev/null && echo "Deleted branch: $branch_to_delete"
      fi
    fi
  } || { echo "Error: Failed to remove" >&2; return 1; }
}

# ─────────────────────────────────────────────────────────────────────────────
# Zsh Completions
# ─────────────────────────────────────────────────────────────────────────────

_gwt_branches() {
  local branches=()
  local porcelain=$(git worktree list --porcelain 2>/dev/null)
  while IFS= read -r line; do
    [[ "$line" == branch* ]] && branches+=("${line#branch refs/heads/}")
  done <<< "$porcelain"
  _describe 'branches' branches
}

_gwt_git_branches() {
  local branches=(${(f)"$(git branch -a --format='%(refname:short)' 2>/dev/null)"})
  _describe 'branches' branches
}

_gwt-create() {
  _arguments '-h[Help]' '--help[Help]' '-l[Local branch]' '--local[Local branch]' \
    '-d[Dangerous mode]' '--dangerous[Dangerous mode]' \
    '-b[Base branch]:branch:_gwt_git_branches' '1:name:'
}

_gwt-switch() {
  _arguments '-h[Help]' '--help[Help]' \
    '-d[Dangerous mode]' '--dangerous[Dangerous mode]' '1:branch:_gwt_branches'
}

_gwt-remove() {
  _arguments '-h[Help]' '--help[Help]' '-f[Force]' '--force[Force]' \
    '-k[Keep branch]' '--keep-branch[Keep branch]' '1:branch:_gwt_branches'
}

# Register completions
[[ -n "$ZSH_VERSION" ]] && (( $+functions[compdef] )) && {
  compdef _gwt-create gwt-create 2>/dev/null
  compdef _gwt-switch gwt-switch 2>/dev/null
  compdef _gwt-remove gwt-remove 2>/dev/null
}
