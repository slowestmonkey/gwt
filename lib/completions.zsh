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

_gwt_provider_names() {
  local providers=(${(k)GWT_PROVIDERS})
  _describe 'providers' providers
}

_gwt-create() {
  _arguments \
    '-h[Show help]' '--help[Show help]' \
    '-l[From current branch]' '--local[From current branch]' \
    '-d[Dangerous mode]' '--dangerous[Dangerous mode]' \
    '-s[Safe mode]' '--safe[Safe mode]' \
    '-b[Base branch]:branch:_gwt_git_branches' \
    '1:name:'
}

_gwt-switch() {
  _arguments \
    '-h[Show help]' '--help[Show help]' \
    '-n[No AI]' '--no-ai[No AI]' \
    '-d[Dangerous mode]' '--dangerous[Dangerous mode]' \
    '-s[Safe mode]' '--safe[Safe mode]' \
    '1:branch:_gwt_branches'
}

_gwt-remove() {
  _arguments \
    '-h[Show help]' '--help[Show help]' \
    '-f[Force]' '--force[Force]' \
    '-k[Keep branch]' '--keep-branch[Keep branch]' \
    '1:branch:_gwt_branches'
}

_gwt-clean() {
  _arguments \
    '-h[Show help]' '--help[Show help]' \
    '-f[Force]' '--force[Force]'
}

_gwt-config() {
  local -a subcmds
  subcmds=(
    'provider:Set or select provider'
    'edit:Edit config file'
    'set:Set config value'
  )
  
  _arguments -C \
    '-h[Show help]' '--help[Show help]' \
    '1:command:->subcmd' \
    '2:arg:->arg'
  
  case "$state" in
    subcmd) _describe 'command' subcmds ;;
    arg)
      case "$words[2]" in
        provider) _gwt_provider_names ;;
        set) _describe 'key' '(GWT_PROVIDER GWT_DEBUG)' ;;
      esac
      ;;
  esac
}

_gwt() {
  local -a commands
  commands=(
    'create:Create worktree + launch AI'
    'list:List worktrees'
    'ls:List worktrees'
    'switch:Switch to worktree'
    'remove:Remove worktree'
    'rm:Remove worktree'
    'clean:Remove clean worktrees'
    'config:Show/edit config'
    'help:Show help'
  )
  
  _arguments -C \
    '-h[Show help]' '--help[Show help]' \
    '-v[Show version]' '--version[Show version]' \
    '--debug[Debug output]' \
    '1:command:->command' \
    '*::arg:->args'
  
  case "$state" in
    command) _describe 'command' commands ;;
    args)
      case "$words[1]" in
        create)      _gwt-create ;;
        switch)      _gwt-switch ;;
        remove|rm)   _gwt-remove ;;
        clean)       _gwt-clean ;;
        config)      _gwt-config ;;
        help)        _describe 'command' '(create list switch remove clean config)' ;;
      esac
      ;;
  esac
}

_gwt_register_completions() {
  [[ -n "$ZSH_VERSION" ]] && (( $+functions[compdef] )) && {
    compdef _gwt gwt 2>/dev/null
  }
}
