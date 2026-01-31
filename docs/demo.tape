# GWT Demo - Git Worktree Manager for AI Coding Assistants
# Theme: Catppuccin Mocha
#
# Run: ./docs/demo-setup.sh && vhs docs/demo.tape

Output docs/demo.gif

Set Shell zsh
Set FontSize 14
Set Width 1200
Set Height 700
Set Padding 20
Set TypingSpeed 40ms
Set Theme "Catppuccin Mocha"

# --- HIDDEN SETUP ---
Hide
Type "source ~/.gwt/gwt.zsh && cd /tmp/gwt-demo-repo && clear"
Enter
Type "clear"
Enter
Sleep 500ms
Show

# --- DEMO START ---
Sleep 1s

# Create first worktree
Type "gwt create -l quasar-feature -d"
Enter
Sleep 2s

# Give Claude a task
Type "implement quasar particle beam renderer"
Sleep 1s

# Exit Claude Code
Ctrl+C
Sleep 1s
Type "/exit"
Enter
Sleep 2s

# Create second worktree
Type "gwt create -l quantum-bugfix -d"
Enter
Sleep 2s

# Give Claude another task
Type "fix quantum entanglement sync issue"
Sleep 1s

# Interrupt Claude Code
Ctrl+C
Sleep 1s

# Simulate change
Type "!echo SIMUALTE_CHANGE=entangled > fix.txt && cat fix.txt"
Enter
Sleep 1500ms

# Exit Claude Code
Type "/exit"
Enter
Sleep 2s

# Back to main
Type "gwt switch main -n"
Enter
Sleep 500ms

# List worktrees
Type "gwt list"
Enter
Sleep 3s

Type "Quantum and quasar changes won't interfere due to separate worktrees."
Sleep 3s
Ctrl+C

# Force remove dirty worktree
Type "gwt remove quantum-bugfix -f"
Enter
Sleep 1s

# Final list
Type "gwt list"
Enter
Sleep 3s
