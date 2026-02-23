# Design: Remote Branch Support in `gwt switch`

## Problem

When a teammate creates a PR with a remote branch, there's no easy way to check it out into a worktree for local review. Currently `gwt switch` only works with existing local worktrees.

## Solution

Extend `gwt switch` to auto-detect remote branches. When no local worktree is found, fetch from origin and create a worktree tracking the remote branch.

## Flow

```
gwt switch <branch>
  ├─ Found local worktree? → cd + launch AI (unchanged)
  └─ Not found?
       ├─ git fetch origin
       ├─ Found origin/<branch>? → create worktree tracking remote → cd + launch AI
       └─ Not found? → error (no local or remote match)
```

## Changes

### `lib/commands.zsh` — `_gwt_cmd_switch`
- When `_gwt_find_path` fails, call `_gwt_switch_remote` instead of returning error
- `_gwt_switch_remote`: fetches, finds remote branch, creates worktree, copies .env, npm install prompt, launches provider

### `lib/git.zsh`
- Add `_gwt_find_remote_branch`: given a search term, find matching `origin/*` branch (exact match first, then partial)

### `lib/commands.zsh` — `_gwt_cmd_list`
- Add remote tracking indicator to worktree list output (show tracking branch info)

### `lib/help.zsh` — `_gwt_help_switch`
- Document remote branch auto-detection
- Add example: `gwt switch teammate-feature`

### `lib/completions.zsh` — `_gwt-switch`
- Completion groups: local worktree branches first, then remote branches
- Remote branches filtered to exclude ones already checked out locally

## Key Implementation Details

- Worktree creation: `git worktree add --track -b <local-name> <path> origin/<branch>`
- Reuses `_gwt_worktree_path` for path generation
- Auto-fetch: always runs `git fetch origin` before remote lookup
- .env copy and npm install prompts reused from `_gwt_cmd_create`
- AI provider launch: same behavior as regular switch (respects `-n`, `-s`, `-d`)

## UX

```
$ gwt switch feature-auth
Fetching from origin...
Creating worktree for remote branch: origin/feature-auth
Creating: ~/.gwt-worktrees/myproject-abc123/feature-auth (tracking origin/feature-auth)
Found package.json. Install dependencies? [y/N]:
```
