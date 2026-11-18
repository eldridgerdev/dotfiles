# Global Claude Code Settings

Applies to every project. A project's own `CLAUDE.md` wins where they differ.

## Models and subagents

- Keep a session on one model. The prompt cache is per model, so switching
  mid-session re-reads the whole context uncached.
- Pass `model` on every Agent call; an omitted `model` inherits the session's,
  which may be the most expensive one. Use the cheapest tier that fits:
   - `haiku`: searching, lookups, running checks and reading their output,
     summarizing a file or diff.
   - `sonnet`: implementing a change that is already decided, tests for a
     stated behavior, doc updates.
   - `opus`: design, planning, investigation, bugs with an unknown cause.
   - `fable`: only when I ask.
- Delegate when only the conclusion matters and the path to it is noisy
  (broad searches, test and CI logs), or when the work is self-contained and
  fits a short brief. Do small edits and anything that depends on our
  conversation inline: a subagent starts cold and re-reading costs more.
- A brief names the files, the decision already made, the acceptance check,
  and what to return (a few lines, not a transcript). Run independent agents
  in one message so they go in parallel.
- Prefer a project's own agents (`.claude/agents/`) over generic ones.

## Shell

- My login shell is fish; Bash tool commands run in bash.
- When I have to run a command myself (for example, a safety restriction),
  first ask whether to open a tmux pane in the current directory, then give
  me the command to run there:

  ```bash
  tmux split-window -h -c "#{pane_current_path}"
  ```

- In bash scripts that locate files relative to themselves, use `$0`, not
  `${BASH_SOURCE[0]}`, which misresolves when invoked from fish:

  ```bash
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  ```

## Markdown files

When writing or editing `.md` files:

- Blank line after every heading and around code blocks, lists and block
  quotes. No consecutive blank lines, no trailing whitespace, one newline at
  end of file.
- Wrap prose under 80 characters. URLs, code blocks and tables may exceed it.
- ATX headings (`#`). `-` for unordered lists, `1.` for ordered; nest with 3
  spaces and align continuation lines with the item text.
- Every code block names a language: `bash` for shell commands, `text` for
  file trees and terminal output.
