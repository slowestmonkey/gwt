# gwt

Run multiple AI coding sessions on different branches. No conflicts.

![DEMO](https://github.com/slowestmonkey/gwt/blob/db0afca89bfc2b4acb0eb5a7187cc9c4673fa5af/docs/demo.gif?raw=true)

**Before:** `git stash && git checkout fix && claude` — conflicts, context lost

**After:** `gwt create bugfix-y` — parallel session, isolated

## 🐙 Why

AI assistants are tied to your working directory. `gwt` wraps git worktrees to give each task its own directory + AI session.

- Auto-launches your AI assistant
- Copies `.env`, prompts `npm install`
- Tab completion, session tracking
- Works with Claude, OpenCode, Aider, Cursor, any

## 🦊 Install

```bash
curl -fsSL https://raw.githubusercontent.com/slowestmonkey/gwt/main/install.sh | sh
```

Or manually:
```bash
git clone https://github.com/slowestmonkey/gwt.git ~/.gwt
echo 'source ~/.gwt/gwt.zsh' >> ~/.zshrc
```

**Then restart your shell.**

## 🦩 Commands

```bash
gwt create <name>           # Create worktree + launch AI
gwt create -l <name>        # From current branch
gwt create -b dev <name>    # From specific branch

gwt list                    # List worktrees (alias: ls)
gwt switch <branch>         # Switch + launch AI
gwt switch -n <branch>      # Switch only (no AI)

gwt remove <branch>         # Remove worktree + branch (alias: rm)
gwt remove -k <branch>      # Keep branch
gwt clean                   # Remove all clean worktrees

gwt config                  # Show config
gwt config provider claude  # Set provider
gwt config edit             # Edit config file
```

**Flags:** `-s` safe mode, `-d` dangerous mode, `-f` force, `-h` help

## 🦚 Providers

| Provider | Command | Safe/Dangerous |
|----------|---------|----------------|
| Claude Code | `claude` | Yes |
| OpenCode | `opencode` | No |
| Aider | `aider` | No |
| Cursor | `cursor` | No |

First run auto-detects installed providers.

## 🦎 Config

```bash
# Set provider
gwt config provider opencode

# Or edit directly
gwt config edit

# Or environment variable
export GWT_PROVIDER=opencode
```

**Config locations:** `./.gwt.conf` > `~/.config/gwt/config` > `~/.gwt.conf`

### Custom Providers

```bash
# In ~/.config/gwt/providers.d/myai.zsh
GWT_PROVIDERS[myai]="myai-cli|||My AI Tool"
```

## 🐠 License

MIT
