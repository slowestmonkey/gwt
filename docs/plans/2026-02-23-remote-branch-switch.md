# Remote Branch Switch Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extend `gwt switch` to auto-detect remote branches, fetch them, and create tracking worktrees — enabling local PR review with one command.

**Architecture:** When `_gwt_find_path` fails to find a local worktree, the switch command falls back to fetching from origin and checking for a matching remote branch. If found, it creates a worktree tracking that remote branch, reusing existing path/env/install logic from `_gwt_cmd_create`.

**Tech Stack:** Zsh, Git (worktree, fetch, show-ref, branch)

---

### Task 1: Add `_gwt_find_remote_branch` helper

**Files:**
- Modify: `lib/git.zsh:104` (append after `_gwt_find_path`)

**Step 1: Write the helper function**

Add at end of `lib/git.zsh`:

```zsh
# Find remote branch by name (exact match first, then partial)
_gwt_find_remote_branch() {
  local search="$1"
  local exact="" partial=()

  local ref
  for ref in $(git branch -r --format='%(refname:short)' 2>/dev/null); do
    # Skip HEAD pointer
    [[ "$ref" == */HEAD ]] && continue
    # Strip "origin/" prefix for matching
    local branch_name="${ref#origin/}"
    if [[ "$branch_name" == "$search" ]]; then
      exact="$branch_name"
      break
    elif [[ "$branch_name" == *"$search"* ]]; then
      partial+=("$branch_name")
    fi
  done

  if [[ -n "$exact" ]]; then
    echo "$exact"
    return 0
  fi

  case ${#partial[@]} in
    0)
      echo "gwt: no remote branch matches '$search'" >&2
      return 1
      ;;
    1)
      echo "${partial[1]}"
      return 0
      ;;
    *)
      echo "gwt: multiple remote branches match '$search':" >&2
      for p in "${partial[@]}"; do
        echo "  - origin/$p" >&2
      done
      echo "gwt: please be more specific" >&2
      return 1
      ;;
  esac
}
```

**Step 2: Test manually**

Source gwt and run in a git repo with remote branches:
```bash
source gwt.zsh
_gwt_find_remote_branch "main"     # should return "main"
_gwt_find_remote_branch "nonexist" # should error
```

**Step 3: Commit**

```bash
git add lib/git.zsh
git commit -m "feat: add _gwt_find_remote_branch helper"
```

---

### Task 2: Extract shared setup logic from `_gwt_cmd_create`

**Files:**
- Modify: `lib/commands.zsh:74-100` (extract post-create logic into `_gwt_post_create`)

The `.env` copy and `npm install` prompt logic in `_gwt_cmd_create` (lines 76-100) needs to be reusable. Extract it into a helper.

**Step 1: Add `_gwt_post_create` helper**

Add before `_gwt_cmd_create` in `lib/commands.zsh` (at line 1, after the header comment):

```zsh
# Shared post-worktree-creation setup (npm install, .env copy)
_gwt_post_create() {
  # Optional: install dependencies
  [[ -f "package.json" ]] && {
    echo -n "Found package.json. Install dependencies? [y/N]: "
    read -r response
    [[ "$response" =~ ^[Yy]$ ]] && npm install
  }

  # Optional: copy .env files
  local main_repo=$(_gwt_main_repo)
  local env_files=("${(@f)$(find "$main_repo" -maxdepth 3 -name ".env*" -type f 2>/dev/null)}")
  if [[ ${#env_files[@]} -gt 0 && -n "${env_files[1]}" ]]; then
    echo -n "Found ${#env_files[@]} .env file(s). Copy? [y/N]: "
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
  fi
}
```

**Step 2: Replace duplicated code in `_gwt_cmd_create`**

Replace lines 76-98 of `_gwt_cmd_create` (the `package.json` + `.env` blocks) with:

```zsh
  _gwt_post_create
```

So the end of `_gwt_cmd_create` becomes:

```zsh
  cd "$wt_path" || { echo "gwt: failed to enter worktree" >&2; return 1; }

  _gwt_post_create

  _gwt_launch_provider "$mode"
}
```

**Step 3: Source and verify `gwt create` still works**

```bash
source gwt.zsh
gwt create test-extract -l  # should behave identically
gwt rm test-extract
```

**Step 4: Commit**

```bash
git add lib/commands.zsh
git commit -m "refactor: extract _gwt_post_create for reuse"
```

---

### Task 3: Add remote branch fallback to `_gwt_cmd_switch`

**Files:**
- Modify: `lib/commands.zsh:155-184` (`_gwt_cmd_switch` function)

**Step 1: Rewrite `_gwt_cmd_switch` with remote fallback**

Replace the current `_gwt_cmd_switch` (lines 155-184) with:

```zsh
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

  # Try local worktree first
  local wt_path
  wt_path=$(_gwt_find_path "$wt_branch" 2>/dev/null)

  if [[ -n "$wt_path" ]]; then
    # Local worktree found
    cd "$wt_path" || { echo "gwt: failed to enter worktree at $wt_path" >&2; return 1; }
    echo "Switched to: $wt_path"
    $no_ai || _gwt_launch_provider "$mode"
    return $?
  fi

  # Fallback: try remote branch
  echo "Fetching from origin..."
  git fetch origin 2>/dev/null || { echo "gwt: failed to fetch from origin" >&2; return 1; }

  local remote_branch
  remote_branch=$(_gwt_find_remote_branch "$wt_branch") || return 1

  echo "Creating worktree for remote branch: origin/$remote_branch"

  wt_path=$(_gwt_worktree_path "$remote_branch")
  mkdir -p "$(dirname "$wt_path")"

  # Reuse existing worktree
  if [[ -d "$wt_path" ]]; then
    echo "Worktree exists: $wt_path"
    cd "$wt_path" || { echo "gwt: failed to enter worktree" >&2; return 1; }
    $no_ai || _gwt_launch_provider "$mode"
    return $?
  fi

  # Create worktree tracking remote branch
  echo "Creating: $wt_path (tracking origin/$remote_branch)"
  git worktree add --track -b "$remote_branch" "$wt_path" "origin/$remote_branch" || {
    echo "gwt: failed to create worktree" >&2
    return 1
  }

  cd "$wt_path" || { echo "gwt: failed to enter worktree" >&2; return 1; }

  _gwt_post_create
  $no_ai || _gwt_launch_provider "$mode"
}
```

**Step 2: Test manually**

In a repo that has remote branches not checked out locally:
```bash
source gwt.zsh
gwt switch <remote-branch-name>   # should fetch, create worktree, cd
gwt list                           # should show new worktree
gwt rm <remote-branch-name>        # cleanup
```

**Step 3: Commit**

```bash
git add lib/commands.zsh
git commit -m "feat: gwt switch auto-detects remote branches"
```

---

### Task 4: Update `gwt list` with tracking indicator

**Files:**
- Modify: `lib/commands.zsh:106-150` (`_gwt_cmd_list` function)

**Step 1: Add tracking info to list output**

In `_gwt_cmd_list`, after the ahead/behind calculation (around line 140), add tracking branch display. Replace the status output section. The key change is adding a `tracking` variable:

After the line `if git -C "$wt_path" rev-parse --abbrev-ref '@{upstream}' &>/dev/null; then`, capture the upstream name:

```zsh
      local tracking=""
      if git -C "$wt_path" rev-parse --abbrev-ref '@{upstream}' &>/dev/null; then
        tracking=$(git -C "$wt_path" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null)
        local ahead=$(git -C "$wt_path" rev-list --count '@{upstream}..HEAD' 2>/dev/null)
        local behind=$(git -C "$wt_path" rev-list --count 'HEAD..@{upstream}' 2>/dev/null)
        [[ "$ahead" -gt 0 ]] && status_text="$status_text ↑$ahead"
        [[ "$behind" -gt 0 ]] && status_text="$status_text ↓$behind"
      fi
```

Then in the output lines, append tracking info. Change the branch display lines to:

```zsh
      local tracking_text=""
      [[ -n "$tracking" ]] && tracking_text=" \033[90m← $tracking\033[0m"

      if [[ -n "$indicator" ]]; then
        echo "  \033[32m$indicator$wt_branch\033[0m$tracking_text$session_indicator  $status_text"
      else
        echo "  \033[34m$wt_branch\033[0m$tracking_text$session_indicator  $status_text"
      fi
```

**Step 2: Test manually**

```bash
source gwt.zsh
gwt list  # worktrees tracking remotes should show "← origin/branch"
```

**Step 3: Commit**

```bash
git add lib/commands.zsh
git commit -m "feat: gwt list shows remote tracking info"
```

---

### Task 5: Update completions for `gwt switch`

**Files:**
- Modify: `lib/completions.zsh:33-40` (`_gwt-switch` function)
- Modify: `lib/completions.zsh:1-11` (add remote branches helper)

**Step 1: Add remote branches completion helper**

Add after `_gwt_branches` (around line 11):

```zsh
_gwt_remote_branches() {
  local -a remote_branches local_branches
  # Get local worktree branches
  while IFS= read -r line; do
    [[ "$line" == branch* ]] && local_branches+=("${line#branch refs/heads/}")
  done <<< "$(git worktree list --porcelain 2>/dev/null)"
  # Get remote branches, excluding ones already in local worktrees
  local ref branch_name
  for ref in $(git branch -r --format='%(refname:short)' 2>/dev/null); do
    [[ "$ref" == */HEAD ]] && continue
    branch_name="${ref#origin/}"
    # Skip if already a local worktree
    if (( ! ${local_branches[(Ie)$branch_name]} )); then
      remote_branches+=("$branch_name")
    fi
  done
  _describe 'remote branches' remote_branches
}
```

**Step 2: Update `_gwt-switch` to use grouped completions**

Replace the `_gwt-switch` function:

```zsh
_gwt-switch() {
  _arguments \
    '-h[Show help]' '--help[Show help]' \
    '-n[No AI]' '--no-ai[No AI]' \
    '-d[Dangerous mode]' '--dangerous[Dangerous mode]' \
    '-s[Safe mode]' '--safe[Safe mode]' \
    '1:branch:->branch'

  case "$state" in
    branch)
      _alternative \
        'local:local worktree:_gwt_branches' \
        'remote:remote branch:_gwt_remote_branches'
      ;;
  esac
}
```

**Step 3: Test manually**

```bash
source gwt.zsh
gwt switch <TAB>  # should show local first, then remote
```

**Step 4: Commit**

```bash
git add lib/completions.zsh
git commit -m "feat: switch completions show local then remote branches"
```

---

### Task 6: Update help text

**Files:**
- Modify: `lib/help.zsh:79-97` (`_gwt_help_switch` function)

**Step 1: Update switch help**

Replace `_gwt_help_switch`:

```zsh
_gwt_help_switch() {
  cat <<EOF
gwt switch - Switch to worktree and optionally launch AI

USAGE
  gwt switch [options] <branch-name>

OPTIONS
  -n, --no-ai      Just cd, don't launch AI
  -s, --safe       Launch in safe mode
  -d, --dangerous  Launch in dangerous mode
  -h, --help       Show this help

REMOTE BRANCHES
  If no local worktree matches, gwt auto-fetches from origin
  and creates a worktree tracking the remote branch.

EXAMPLES
  gwt switch feature-auth      Switch + launch AI
  gwt switch -n feature-auth   Just cd
  gwt switch feat              Partial match
  gwt switch pr-feature        Auto-fetch remote branch
EOF
}
```

**Step 2: Commit**

```bash
git add lib/help.zsh
git commit -m "docs: update switch help with remote branch info"
```

---

### Task 7: Update README

**Files:**
- Modify: `README.md`

**Step 1: Add remote branch section to README**

Add a "PR Review" or "Remote Branches" section in the README under usage examples:

```markdown
### Review a PR locally

```bash
gwt switch teammate-feature    # auto-fetches and creates worktree
gwt switch -n teammate-feature # just cd, no AI launch
```

`gwt switch` auto-detects remote branches: if no local worktree matches, it fetches from origin and creates a tracking worktree.
```

Also update the `switch` row in the commands table to mention remote auto-detection.

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add remote branch switch to README"
```
