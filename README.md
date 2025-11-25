# gwt-claude

Git worktree manager for parallel Claude Code (CLI) sessions
```
Claude Code = 👍
Git worktree = 👍
Claude Code + Git worktree = 👍²
```

## Why?

Run multiple Claude Code sessions on different branches simultaneously. Each session gets its own directory, so no git conflicts or context switching.

```bash
# Start working on a feature
gwt-create auth-refactor

# Meanwhile, in another terminal, start a different task
gwt-create fix-billing-bug

# Two Claude sessions, two branches, zero conflicts

# Later, pick up where you left off
gwt-switch auth-refactor
```

## Prerequisites

- **zsh** - Shell (default on macOS)
- **git** - Version control
- **claude** - [Claude Code CLI](https://code.claude.com/docs/en/setup)

## Install

```bash
# Clone to any location
git clone https://github.com/slowestmonkey/gwt-claude.git ~/.gwt-claude

# Add to ~/.zshrc
echo 'source ~/.gwt-claude/gwt.zsh' >> ~/.zshrc

# Reload shell
source ~/.zshrc
```

## Commands

```bash
gwt-create <name>           # Create from main + open Claude Code
gwt-create -l <name>        # Create from current branch (-l = local)
gwt-create -b dev <name>    # Create from specific branch
                            # Auto-prompts for npm install if package.json found
gwt-list                    # List all worktrees
gwt-switch <branch>         # Switch to worktree + open Claude Code
gwt-remove <branch>         # Remove worktree (with confirmation)
gwt-remove -f <branch>      # Force remove
```

All commands support `-h` / `--help` and **tab completion** for branch names.

## Storage

Worktrees are stored in: `~/.claude-worktrees/{repo}/{name}`