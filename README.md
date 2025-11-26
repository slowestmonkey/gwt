# gwt-claude

**Run multiple Claude Code CLI sessions on different branches without conflicts.**

We don't need a "Next-Gen AI IDE" that tries to reinvent everything. Claude Code CLI is already excellent at what it does! The only missing piece is session isolation.

### The Math

```text
Claude Code  = 👽
Git worktree = 🚜
Combined     = 🛸 (Crop circles completed in seconds)
```

## 🦑 The Problem

Claude Code is great, but it lives in your current directory ("working tree"). If you want to multitask - say, building a feature while fixing a hot-fix bug - you are stuck switching branches, stashing changes, and confusing the AI (and yourself).

## 🧽 The Solution

Git worktrees allow you to check out multiple branches in separate folders simultaneously.

```bash
gwt-create feature-auth    # 1. Spawns a new folder/worktree
                           # 2. Launches Claude in that isolated context

gwt-create fix-payments    # New terminal, new branch, fresh Claude instance.
                           # Zero context bleed.

# Later...
gwt-switch feature-auth    # Teleport back to where you left off.
gwt-remove fix-payments    # Nuke the folder when the PR is merged.
```

That's it. Four commands that handle 90% of the "I need to do two things at once" workflow.

## 🦩 Install

```bash
git clone https://github.com/slowestmonkey/gwt-claude.git ~/.gwt-claude
echo 'source ~/.gwt-claude/gwt.zsh' >> ~/.zshrc
source ~/.zshrc
```

**Requirements:** zsh, git, and [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed.

## 🦚 Cheat Sheet

```bash
gwt-create <name>           # Create worktree from main
gwt-create -l <name>        # Create from your CURRENT branch (local)
gwt-create -b dev <name>    # Create from a specific base branch
gwt-list                    # Show where your brain is currently split
gwt-switch <branch>         # Jump to a worktree
gwt-remove <branch>         # Remove worktree
gwt-remove -f <branch>      # Force remove (YOLO mode)
```

*All commands support `-h` and tab completion.*
