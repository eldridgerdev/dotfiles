# Global Claude Code Settings

## Manual Command Execution

When you need to tell me to run a command manually (e.g., due to safety restrictions), always ask if I want you to open a new tmux pane in the current directory first. Use:

```bash
tmux split-window -h -c "#{pane_current_path}"
```

Then provide the command for me to run in that pane.

## Bash Script Path Resolution

When writing or fixing bash scripts that need to reference files relative to the script's location, use `$0` instead of `${BASH_SOURCE[0]}` for directory detection:

```bash
# Reliable - works when invoked from fish shell or other contexts
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Unreliable - BASH_SOURCE may not resolve correctly in all contexts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

This is especially important when the default shell is fish, as `BASH_SOURCE` can behave unexpectedly when bash scripts are invoked through different shell contexts.
