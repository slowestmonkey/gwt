# gwt-claude

Run multiple Claude Code sessions on different branches. No conflicts.

> [Claude Code](https://code.claude.com/docs) is Anthropic's CLI agent that writes and edits code in your terminal.

**zsh only.**

## 🦑 Why

Claude Code lives in your working directory. Want to build a feature while fixing a bug? You're stuck switching branches, stashing, and confusing everyone.

Git worktrees let you check out multiple branches in separate folders. This tool wraps that and auto-launches Claude Code in each worktree.

## 🦊 Workflow

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Your Main Repository                         │
│                         ~/projects/my-app                           │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ gwt-create <branch>
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    ~/.claude-worktrees/my-app/                      │
│                                                                     │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐      │
│  │   feature-auth  │  │    fix-bug-42   │  │  refactor-api   │      │
│  │                 │  │                 │  │                 │      │
│  │  ┌───────────┐  │  │  ┌───────────┐  │  │  ┌───────────┐  │      │
│  │  │  Claude   │  │  │  │  Claude   │  │  │  │  Claude   │  │      │
│  │  │   Code    │  │  │  │   Code    │  │  │  │   Code    │  │      │
│  │  └───────────┘  │  │  └───────────┘  │  │  └───────────┘  │      │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘      │
│                                                                     │
│         gwt-switch ◄────────────────────────► gwt-remove            │
└─────────────────────────────────────────────────────────────────────┘
```

## 🐙 Why not just git worktrees?

You could use `git worktree` directly, but you'd miss:

- **Auto-launch Claude** — Each worktree opens with its own Claude Code session
- **Environment sync** — Copies `.env` files from main repo to new worktrees
- **Dependency prompts** — Asks to run `npm install` when `package.json` exists
- **Safe mode** — Restrict Claude to read/edit/git tools only (`-s` flag)
- **Tab completion** — Branch names autocomplete in zsh
- **Clean removal** — Single command removes worktree + local branch + remote branch

## 🦩 Install

```bash
git clone https://github.com/slowestmonkey/gwt-claude.git ~/.gwt-claude
echo 'source ~/.gwt-claude/gwt.zsh' >> ~/.zshrc
source ~/.zshrc
```

## 🦚 Commands

```bash
gwt-create <name>           # Create worktree + open Claude
gwt-create -l <name>        # Create from current branch
gwt-create -b dev <name>    # Create from specific branch
gwt-list                    # List worktrees with status
gwt-switch <branch>         # Jump to worktree + open Claude
gwt-remove <branch>         # Remove worktree + delete branch
gwt-remove -k <branch>      # Remove worktree, keep branch
gwt-remove -f <branch>      # Force remove
```

All commands: `-h` for help, tab completion supported.

## 🦔 Limitations

- **zsh only** — Bash support not yet available
- **Requires Claude Code** — Install from [Anthropic](https://code.claude.com/docs/en/setup)
- **Disk space** — Each worktree is a full checkout
- **macOS/Linux** — No Windows support

## 🦎 Alternatives

| Tool | Approach |
|------|----------|
| `git worktree` | Manual worktrees, no Claude integration |
| tmux/screen | Session-based multitasking, not directory-based |
