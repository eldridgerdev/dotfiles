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

This is especially important when the default shell is fish, as `BASH_SOURCE`
can behave unexpectedly when bash scripts are invoked through different shell
contexts.

## Markdown File Formatting

When writing or editing `.md` files, follow these formatting rules:

### Spacing Rules

- Add a blank line after every heading (`#`, `##`, `###`, etc.)
- Add a blank line before and after code blocks (```)
- Add a blank line before and after lists (both ordered and unordered)
- Add a blank line before and after block quotes

### Line Length

- Keep lines under 80 characters
- Wrap long paragraphs and list items to multiple lines
- Exception: URLs, code blocks, and tables may exceed 80 characters

### Code Blocks

- Always specify a language for syntax highlighting (e.g., ```typescript)
- Use ```text for plain text content like file trees or terminal output
- Use ```bash for shell commands

### Lists

- Use `-` for unordered lists (not `*`)
- Use `1.` for ordered lists
- Indent nested list items with 3 spaces
- For multi-line list items, indent continuation lines to align with the text

### Other Rules

- No trailing whitespace at end of lines
- Single blank line at end of file
- No multiple consecutive blank lines
- Use ATX-style headings (`#`) not Setext-style (underlines)
