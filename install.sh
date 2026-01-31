#!/bin/sh
set -e

GWT_DIR="$HOME/.gwt"

echo "Installing gwt..."

# Check for git
if ! command -v git >/dev/null 2>&1; then
  echo "Error: git is required but not installed."
  exit 1
fi

# Detect user's shell
DETECTED_SHELL=$(basename "${SHELL:-/bin/bash}")

case "$DETECTED_SHELL" in
  zsh)
    RC_FILE="$HOME/.zshrc"
    GWT_LOADER="gwt.zsh"
    SHELL_NAME="zsh"
    ;;
  bash)
    RC_FILE="$HOME/.bashrc"
    GWT_LOADER="gwt.bash"
    SHELL_NAME="bash"
    # Check bash version (need 4.2+ for declare -gA associative arrays)
    if command -v bash >/dev/null 2>&1; then
      BASH_MAJOR=$(bash -c 'echo ${BASH_VERSINFO[0]}')
      BASH_MINOR=$(bash -c 'echo ${BASH_VERSINFO[1]}')
      if [ "$BASH_MAJOR" -lt 4 ] || { [ "$BASH_MAJOR" -eq 4 ] && [ "$BASH_MINOR" -lt 2 ]; }; then
        echo "Warning: gwt requires bash 4.2+ for full functionality."
        echo "Your bash version: $(bash --version | head -1)"
        echo ""
        echo "On macOS, you can install a newer bash with:"
        echo "  brew install bash"
        echo "Then add /opt/homebrew/bin/bash to /etc/shells and run:"
        echo "  chsh -s /opt/homebrew/bin/bash"
        echo ""
      fi
    fi
    ;;
  *)
    echo "Warning: Unsupported shell '$DETECTED_SHELL'"
    echo "gwt supports: bash, zsh"
    echo ""
    echo "Defaulting to bash installation..."
    RC_FILE="$HOME/.bashrc"
    GWT_LOADER="gwt.bash"
    SHELL_NAME="bash"
    ;;
esac

echo "Detected shell: $SHELL_NAME"

# Clone or update
if [ -d "$GWT_DIR" ]; then
  echo "Updating existing installation..."
  git -C "$GWT_DIR" pull --quiet
else
  echo "Cloning to $GWT_DIR..."
  git clone --quiet https://github.com/slowestmonkey/gwt.git "$GWT_DIR"
fi

# Add to shell rc file if not already present
SOURCE_LINE="source \"\$HOME/.gwt/$GWT_LOADER\""
# Escape dot in .gwt for proper regex matching
GREP_PATTERN="source.*\\\.gwt/gwt\.\(zsh\|bash\)"

if ! grep -qE "$GREP_PATTERN" "$RC_FILE" 2>/dev/null; then
  echo "" >> "$RC_FILE"
  echo "# gwt - Git Worktree Manager" >> "$RC_FILE"
  echo "$SOURCE_LINE" >> "$RC_FILE"
  echo "Added to $RC_FILE"
else
  # Check if using the correct loader for current shell
  if grep -q "gwt.zsh" "$RC_FILE" 2>/dev/null && [ "$SHELL_NAME" = "bash" ]; then
    echo "Note: $RC_FILE sources gwt.zsh but you're using bash."
    echo "You may want to change it to: source \"\$HOME/.gwt/gwt.bash\""
  elif grep -q "gwt.bash" "$RC_FILE" 2>/dev/null && [ "$SHELL_NAME" = "zsh" ]; then
    echo "Note: $RC_FILE sources gwt.bash but you're using zsh."
    echo "You may want to change it to: source \"\$HOME/.gwt/gwt.zsh\""
  else
    echo "Already in $RC_FILE"
  fi
fi

echo ""
echo "Done! Restart your shell or run:"
echo "  source $RC_FILE"
