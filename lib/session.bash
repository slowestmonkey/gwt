# ─────────────────────────────────────────────────────────────────────────────
# Session Tracking (Bash version)
# ─────────────────────────────────────────────────────────────────────────────

# Start a session (track active AI process)
_gwt_session_start() {
  local pid="$1"
  local provider="$2"
  local wt_path
  wt_path=$(pwd)

  mkdir -p "$GWT_SESSION_DIR"

  # Create session file
  local session_file="$GWT_SESSION_DIR/$(basename "$wt_path").session"
  cat > "$session_file" <<EOF
PID=$pid
PROVIDER=$provider
PATH=$wt_path
STARTED=$(date +%s)
EOF
  _gwt_debug "Session started: $session_file"
}

# End current session
_gwt_session_end() {
  local wt_path
  wt_path=$(pwd)
  local session_file="$GWT_SESSION_DIR/$(basename "$wt_path").session"

  [[ -f "$session_file" ]] && rm -f "$session_file"
  _gwt_debug "Session ended: $session_file"
}

# Check if worktree has active session
_gwt_session_active() {
  local wt_path="$1"
  local session_file="$GWT_SESSION_DIR/$(basename "$wt_path").session"

  [[ ! -f "$session_file" ]] && return 1

  # Read PID and check if process is running
  local pid
  pid=$(grep "^PID=" "$session_file" 2>/dev/null | cut -d= -f2)
  [[ -z "$pid" ]] && return 1

  # Check if process is still running
  if kill -0 "$pid" 2>/dev/null; then
    return 0
  else
    # Stale session file, clean up
    rm -f "$session_file"
    return 1
  fi
}

# Get session info for a worktree
_gwt_session_info() {
  local wt_path="$1"
  local session_file="$GWT_SESSION_DIR/$(basename "$wt_path").session"

  [[ -f "$session_file" ]] && cat "$session_file"
}

# Clean up stale sessions
_gwt_session_cleanup() {
  [[ ! -d "$GWT_SESSION_DIR" ]] && return 0

  local count=0
  # Bash nullglob handling
  local old_nullglob
  old_nullglob=$(shopt -p nullglob 2>/dev/null || echo "shopt -u nullglob")
  shopt -s nullglob

  for session_file in "$GWT_SESSION_DIR"/*.session; do
    local pid
    pid=$(grep "^PID=" "$session_file" 2>/dev/null | cut -d= -f2)
    if [[ -n "$pid" ]] && ! kill -0 "$pid" 2>/dev/null; then
      rm -f "$session_file"
      ((count++))
    fi
  done

  eval "$old_nullglob"

  [[ $count -gt 0 ]] && _gwt_debug "Cleaned up $count stale sessions"
}
