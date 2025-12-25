# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  gwt-claude - Git Worktree Manager for Claude Code                        ║
# ║  Worktrees stored in: ~/.claude-worktrees/{repo}/{branch}                 ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

GWT_ALLOWED_TOOLS=(
  "Read" "Edit" "Write" "Grep" "Glob"
  "Bash(git:*)" "Bash(npm:*)" "Bash(ls:*)" "Bash(cat:*)"
)

# ─────────────────────────────────────────────────────────────────────────────
# Private Helpers
# ─────────────────────────────────────────────────────────────────────────────

_gwt_launch_claude() {
  local mode=$1
  echo "Opening Claude Code..."
  case "$mode" in
    dangerous) claude --dangerously-skip-permissions ;;
    safe)      claude --allowedTools "${GWT_ALLOWED_TOOLS[@]}" ;;
    *)         claude ;;
  esac
}

_gwt_require_repo() {
  git rev-parse --is-inside-work-tree &>/dev/null || {
    echo "Error: Not inside a git repository" >&2
    return 1
  }
}

_gwt_main_repo()      { git worktree list --porcelain | head -1 | sed 's/^worktree //'; }
_gwt_default_branch() { git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main"; }
_gwt_display_path()   { echo "${1/#$HOME/~}"; }

_gwt_worktree_path() {
  local branch_name="$1"
  local repo_name=$(basename "$(_gwt_main_repo)")
  echo "$HOME/.claude-worktrees/${repo_name}/${branch_name//\//-}"
}

_gwt_find_path() {
  local search="$1"
  local exact="" partial=()
  local wt_path="" wt_branch=""

  while IFS= read -r line; do
    [[ "$line" == worktree* ]] && wt_path="${line#worktree }"
    [[ "$line" == branch* ]] && {
      wt_branch="${line#branch refs/heads/}"
      [[ "$wt_branch" == "$search" ]] && exact="$wt_path"
      [[ "$wt_branch" == *"$search"* && -z "$exact" ]] && partial+=("$wt_path")
    }
  done <<< "$(git worktree list --porcelain)"

  [[ -n "$exact" ]] && { echo "$exact"; return 0; }

  case ${#partial[@]} in
    0) echo "Error: No worktree matches '$search'" >&2; return 1 ;;
    1) echo "${partial[1]}" ;;
    *) echo "Error: Multiple matches for '$search':" >&2
       printf '  %s\n' "${partial[@]}" >&2
       return 1 ;;
  esac
}

_gwt_is_protected() {
  local branch="$1" default=$(_gwt_default_branch)
  [[ "$branch" == "$default" || "$branch" == "main" || "$branch" == "master" ]]
}

_gwt_help() {
  cat <<'EOF'
gwt-claude - Git worktree manager for parallel Claude Code sessions

COMMANDS
  gwt-create [-l|-b <branch>] [-d|-s] <name>   Create worktree + open Claude
  gwt-list                                     List worktrees with status
  gwt-switch [-d|-s] <branch>                  Switch to worktree + open Claude
  gwt-remove [-f] [-k] <branch>                Remove worktree and branch

OPTIONS
  -l, --local        Create from current branch (default: main/master)
  -b <branch>        Create from specific branch
  -f, --force        Skip confirmation, remove dirty worktrees
  -k, --keep-branch  Keep the branch when removing worktree
  -h, --help         Show this help

CLAUDE MODES
  (default)          Normal Claude (prompts for each tool)
  -s, --safe         Restricted tools: Read, Edit, Write, Grep, Glob, git, npm, ls, cat
  -d, --dangerous    Skip ALL permission prompts (--dangerously-skip-permissions)

STORAGE
  ~/.claude-worktrees/{repo}/{branch}
EOF
}

# ─────────────────────────────────────────────────────────────────────────────
# Public Commands
# ─────────────────────────────────────────────────────────────────────────────

gwt-create() {
  _gwt_require_repo || return 1

  # Parse arguments
  local base="" name="" local_branch=false mode="default"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)      _gwt_help; return 0 ;;
      -l|--local)     local_branch=true; shift ;;
      -d|--dangerous) mode="dangerous"; shift ;;
      -s|--safe)      mode="safe"; shift ;;
      -b)             base="$2"; shift 2 ;;
      -*)             echo "Error: Unknown option '$1'" >&2; return 1 ;;
      *)              name="$1"; shift ;;
    esac
  done

  [[ -z "$name" ]] && { echo "Usage: gwt-create [-l | -b <branch>] <name>" >&2; return 1; }

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
  if [[ -d "$wt_path" ]]; then
    echo "Worktree exists: $(_gwt_display_path "$wt_path")"
    cd "$wt_path"
    _gwt_launch_claude $mode
    return 0
  fi

  # Create worktree
  echo "Creating: $(_gwt_display_path "$wt_path") (from $base)"
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

  # Optional: copy .env files
  local main_repo=$(_gwt_main_repo)
  local env_files=("${(@f)$(find "$main_repo" -name ".env" -type f 2>/dev/null)}")
  [[ ${#env_files[@]} -gt 0 && -n "${env_files[1]}" ]] && {
    echo "Found ${#env_files[@]} .env file(s) in main repo. Copy to worktree? [y/N]"
    read -r response
    [[ "$response" =~ ^[Yy]$ ]] && {
      for env_file in "${env_files[@]}"; do
        local rel_path="${env_file#$main_repo/}"
        local target_dir="$(dirname "$rel_path")"
        [[ "$target_dir" != "." ]] && mkdir -p "$target_dir"
        cp "$env_file" "$rel_path"
      done
      echo "Copied ${#env_files[@]} .env file(s)"
    }
  }

  _gwt_launch_claude $mode
}

gwt-list() {
  [[ "$1" == "-h" || "$1" == "--help" ]] && { _gwt_help; return 0; }
  _gwt_require_repo || return 1

  local cwd=$(pwd)
  echo "\033[1mGit Worktrees:\033[0m\n"

  local wt_path="" wt_branch="" head_line="" branch_line=""
  while IFS= read -r line; do
    if [[ "$line" == worktree* ]]; then
      wt_path="${line#worktree }"
      read -r head_line
      read -r branch_line
      wt_branch=$([[ "$branch_line" == branch* ]] && echo "${branch_line#branch refs/heads/}" || echo "(detached)")

      # Build status
      local indicator="" status_text=""
      [[ "$cwd" == "$wt_path"* ]] && indicator="→ "

      # Dirty/clean
      if [[ -n "$(git -C "$wt_path" status --porcelain 2>/dev/null)" ]]; then
        status_text="\033[33m●\033[0m dirty"
      else
        status_text="\033[32m●\033[0m clean"
      fi

      # Ahead/behind
      if git -C "$wt_path" rev-parse --abbrev-ref '@{upstream}' &>/dev/null; then
        local ahead=$(git -C "$wt_path" rev-list --count '@{upstream}..HEAD' 2>/dev/null)
        local behind=$(git -C "$wt_path" rev-list --count 'HEAD..@{upstream}' 2>/dev/null)
        [[ "$ahead" -gt 0 ]] && status_text="$status_text ↑$ahead"
        [[ "$behind" -gt 0 ]] && status_text="$status_text ↓$behind"
      fi

      # Output
      if [[ -n "$indicator" ]]; then
        echo "  \033[32m$indicator$wt_branch\033[0m  $status_text"
      else
        echo "  \033[34m$wt_branch\033[0m  $status_text"
      fi
      echo "    $(_gwt_display_path "$wt_path")\n"
    fi
  done <<< "$(git worktree list --porcelain)"
}

gwt-switch() {
  _gwt_require_repo || return 1

  # Parse arguments
  local wt_branch="" mode="default"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)      _gwt_help; return 0 ;;
      -d|--dangerous) mode="dangerous"; shift ;;
      -s|--safe)      mode="safe"; shift ;;
      -*)             echo "Error: Unknown option '$1'" >&2; return 1 ;;
      *)              wt_branch="$1"; shift ;;
    esac
  done

  [[ -z "$wt_branch" ]] && { echo "Usage: gwt-switch <branch>" >&2; gwt-list; return 1; }

  local wt_path
  wt_path=$(_gwt_find_path "$wt_branch") || return 1
  cd "$wt_path"
  echo "Switched to: $(_gwt_display_path "$wt_path")"
  _gwt_launch_claude $mode
}

gwt-remove() {
  _gwt_require_repo || return 1

  # Parse arguments
  local force=false keep_branch=false wt_branch=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)        _gwt_help; return 0 ;;
      -f|--force)       force=true; shift ;;
      -k|--keep-branch) keep_branch=true; shift ;;
      -*)               echo "Error: Unknown option '$1'" >&2; return 1 ;;
      *)                wt_branch="$1"; shift ;;
    esac
  done

  [[ -z "$wt_branch" ]] && { echo "Usage: gwt-remove [-f] [-k] <branch>" >&2; gwt-list; return 1; }

  # Safety: protect main branches
  _gwt_is_protected "$wt_branch" && {
    echo "Error: Cannot remove protected branch '$wt_branch'" >&2
    return 1
  }

  local wt_path
  wt_path=$(_gwt_find_path "$wt_branch") || return 1
  local main=$(_gwt_main_repo)

  # Safety checks
  [[ "$wt_path" == "$main" ]] && { echo "Error: Cannot remove main repository" >&2; return 1; }
  [[ "$(pwd)" == "$wt_path"* ]] && { echo "Error: Cannot remove current worktree. Switch first." >&2; return 1; }

  # Get actual branch name
  local branch_to_delete=""
  while IFS= read -r line; do
    [[ "$line" == worktree* ]] && local wt="${line#worktree }"
    [[ "$line" == branch* ]] && {
      local br="${line#branch refs/heads/}"
      [[ "$wt" == "$wt_path" ]] && branch_to_delete="$br"
    }
  done <<< "$(git worktree list --porcelain)"

  # Dirty check
  [[ -n $(git -C "$wt_path" status --porcelain 2>/dev/null) ]] && ! $force && {
    echo "Warning: Uncommitted changes. Use -f to force." >&2
    return 1
  }

  # Confirm
  ! $force && {
    echo "Remove $(_gwt_display_path "$wt_path")? [y/N]"
    read -r response
    [[ ! "$response" =~ ^[Yy]$ ]] && { echo "Cancelled"; return 0; }
  }

  # Remove worktree
  git worktree remove --force "$wt_path" || { echo "Error: Failed to remove" >&2; return 1; }
  echo "Removed: $(_gwt_display_path "$wt_path")"
  git worktree prune

  # Delete branch
  if ! $keep_branch && [[ -n "$branch_to_delete" ]] && ! _gwt_is_protected "$branch_to_delete"; then
    git branch -D "$branch_to_delete" 2>/dev/null && echo "Deleted local branch: $branch_to_delete"

    # Offer to delete remote
    git fetch --prune origin 2>/dev/null
    if git show-ref --verify --quiet "refs/remotes/origin/$branch_to_delete"; then
      echo "Remote branch 'origin/$branch_to_delete' exists. Delete it? [y/N]"
      read -r response
      [[ "$response" =~ ^[Yy]$ ]] && {
        git push origin --delete "$branch_to_delete" 2>/dev/null && \
          echo "Deleted remote branch: origin/$branch_to_delete" || \
          echo "Warning: Failed to delete remote branch" >&2
      }
    fi
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Zsh Completions
# ─────────────────────────────────────────────────────────────────────────────

_gwt_branches() {
  local branches=()
  while IFS= read -r line; do
    [[ "$line" == branch* ]] && branches+=("${line#branch refs/heads/}")
  done <<< "$(git worktree list --porcelain 2>/dev/null)"
  _describe 'branches' branches
}

_gwt_git_branches() {
  local branches=(${(f)"$(git branch -a --format='%(refname:short)' 2>/dev/null)"})
  _describe 'branches' branches
}

_gwt-create() {
  _arguments '-h[Help]' '--help[Help]' '-l[Local branch]' '--local[Local branch]' \
    '-d[Dangerous mode]' '--dangerous[Dangerous mode]' \
    '-s[Safe mode]' '--safe[Safe mode]' \
    '-b[Base branch]:branch:_gwt_git_branches' '1:name:'
}

_gwt-switch() {
  _arguments '-h[Help]' '--help[Help]' \
    '-d[Dangerous mode]' '--dangerous[Dangerous mode]' \
    '-s[Safe mode]' '--safe[Safe mode]' '1:branch:_gwt_branches'
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
