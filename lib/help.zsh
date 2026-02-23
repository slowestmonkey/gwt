# ─────────────────────────────────────────────────────────────────────────────
# Help System
# ─────────────────────────────────────────────────────────────────────────────

_gwt_help() {
  cat <<EOF
gwt - Git Worktree Manager for AI Coding Assistants (v$GWT_VERSION)

USAGE
  gwt <command> [options] [arguments]

COMMANDS
  create    Create worktree and launch AI assistant
  list      List worktrees with status (alias: ls)
  switch    Switch to worktree and launch AI (-n to skip AI)
  remove    Remove worktree and branch (alias: rm)
  clean     Remove all clean worktrees
  config    Show/edit config, manage providers
  help      Show help for a command

OPTIONS
  -h, --help     Show help
  -v, --version  Show version
  --debug        Enable debug output

EXAMPLES
  gwt create feature-login     Create from default branch
  gwt create -l fix-bug        Create from current branch
  gwt switch feature-login     Switch + launch AI
  gwt switch -n feature-login  Switch only (no AI)
  gwt remove feature-login     Remove worktree + branch
  gwt config provider opencode Set provider

PERMISSION MODES
  -s, --safe       Restricted tools (provider-dependent)
  -d, --dangerous  Skip all permission prompts
EOF
}

_gwt_help_create() {
  cat <<EOF
gwt create - Create worktree and launch AI assistant

USAGE
  gwt create [options] <branch-name>

OPTIONS
  -l, --local      Use current branch as base
  -b <branch>      Use specific branch as base
  -s, --safe       Launch in safe mode
  -d, --dangerous  Launch in dangerous mode
  -h, --help       Show this help

EXAMPLES
  gwt create feature-auth
  gwt create -l hotfix-123
  gwt create -b develop new-feat
  gwt create -d feature-quick
EOF
}

_gwt_help_list() {
  cat <<EOF
gwt list - List all worktrees with status

USAGE
  gwt list
  gwt ls

STATUS INDICATORS
  →   Current worktree
  ●   green=clean, yellow=dirty
  ↑n  Commits ahead of remote
  ↓n  Commits behind remote
  ⚡  Active AI session
EOF
}

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

_gwt_help_clean() {
  cat <<EOF
gwt clean - Remove all clean worktrees

USAGE
  gwt clean [-f]

OPTIONS
  -f, --force  Skip confirmation
  -h, --help   Show this help

NOTES
  - Only removes worktrees with no uncommitted changes
  - Skips main repo, current dir, protected branches
  - Also deletes associated branches
EOF
}

_gwt_help_remove() {
  cat <<EOF
gwt remove - Remove worktree and optionally delete branch

USAGE
  gwt remove [options] <branch-name>
  gwt rm [options] <branch-name>

OPTIONS
  -f, --force        Force remove dirty worktree
  -k, --keep-branch  Keep the branch
  -h, --help         Show this help

EXAMPLES
  gwt rm feature-done       Remove + delete branch
  gwt rm -k feature-wip     Keep branch
  gwt rm -f feature-old     Force remove
EOF
}

_gwt_help_config() {
  cat <<EOF
gwt config - Show/edit configuration and manage providers

USAGE
  gwt config                    Show config + providers
  gwt config provider           Interactive provider selection
  gwt config provider <name>    Set provider directly
  gwt config edit               Edit config in \$EDITOR
  gwt config set <key> <value>  Set config value

PROVIDERS
  claude, opencode, aider, cursor

CONFIG FILES (priority order)
  ./.gwt.conf
  ~/.config/gwt/config
  ~/.gwt.conf

CUSTOM PROVIDERS
  Add to ~/.config/gwt/providers.d/myai.zsh:
    GWT_PROVIDERS[myai]="myai-cli|||My AI"
EOF
}
