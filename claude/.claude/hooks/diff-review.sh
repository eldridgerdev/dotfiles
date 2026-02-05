#!/bin/bash
#
# diff-review.sh - Claude Code PreToolUse hook for reviewing file changes
#
# Opens vimdiff directly. Press Enter to approve, r to reject with feedback, q to cancel.
#

set -euo pipefail

HOOK_INPUT=$(cat)
TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // empty')
SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // "unknown"')

if [[ "$TOOL_NAME" != "Edit" && "$TOOL_NAME" != "Write" ]]; then
    exit 0
fi

TOOL_INPUT=$(echo "$HOOK_INPUT" | jq -r '.tool_input // empty')
FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // empty')

if [[ -z "$FILE_PATH" ]]; then
    exit 0
fi

# Get file extension for syntax highlighting
FILE_EXT="${FILE_PATH##*.}"

TEMP_DIR="/tmp/claude-review/$SESSION_ID"
SIGNAL_FILE="$TEMP_DIR/signal"
ORIGINAL_FILE="$TEMP_DIR/original.$FILE_EXT"
PROPOSED_FILE="$TEMP_DIR/proposed.$FILE_EXT"

check_requirements() {
    [[ -n "${TMUX:-}" ]] && command -v tmux &> /dev/null
}

capture_original_file() {
    mkdir -p "$TEMP_DIR"
    rm -f "$SIGNAL_FILE"
    if [[ -f "$FILE_PATH" ]]; then
        cp "$FILE_PATH" "$ORIGINAL_FILE"
    else
        touch "$ORIGINAL_FILE"
    fi
}

create_proposed_file() {
    if [[ "$TOOL_NAME" == "Write" ]]; then
        echo "$TOOL_INPUT" | jq -r '.content // empty' > "$PROPOSED_FILE"
    elif [[ "$TOOL_NAME" == "Edit" ]]; then
        local OLD_STRING_FILE="$TEMP_DIR/old_string"
        local NEW_STRING_FILE="$TEMP_DIR/new_string"
        echo "$TOOL_INPUT" | jq -r '.old_string // empty' > "$OLD_STRING_FILE"
        echo "$TOOL_INPUT" | jq -r '.new_string // empty' > "$NEW_STRING_FILE"
        OLD_FILE="$OLD_STRING_FILE" NEW_FILE="$NEW_STRING_FILE" perl -0777 -pe '
            BEGIN {
                open(F, "<", $ENV{OLD_FILE}) or die; local $/; $old = <F>; close F;
                open(F, "<", $ENV{NEW_FILE}) or die; local $/; $new = <F>; close F;
                chomp $old; chomp $new;
            }
            s/\Q$old\E/$new/s;
        ' "$ORIGINAL_FILE" > "$PROPOSED_FILE"
    fi
}

open_review() {
    local vim_script="$TEMP_DIR/review.vim"
    cat > "$vim_script" << VIMSCRIPT
" Claude Code Review - Enter=approve, r=reject with feedback, q=cancel
let g:signal_file = '${SIGNAL_FILE}'

function! ClaudeApprove()
    call writefile(['approve'], g:signal_file)
    sleep 100m
    qa!
endfunction

function! ClaudeRejectWithFeedback()
    call writefile(['feedback'], g:signal_file)
    sleep 100m
    qa!
endfunction

function! ClaudeCancel()
    call writefile(['cancel'], g:signal_file)
    sleep 100m
    qa!
endfunction

" Enter to approve, r to reject with feedback, q to cancel
nnoremap <CR> :call ClaudeApprove()<CR>
nnoremap r :call ClaudeRejectWithFeedback()<CR>
nnoremap q :call ClaudeCancel()<CR>

" Custom highlight groups
highlight ClaudeHeader guifg=#ffffff guibg=#7c3aed gui=bold ctermbg=93 ctermfg=white cterm=bold
highlight ClaudeFile guifg=#e0e0e0 guibg=#7c3aed gui=NONE ctermbg=93 ctermfg=255 cterm=NONE
highlight ClaudeApprove guifg=#22c55e guibg=#7c3aed gui=bold ctermbg=93 ctermfg=green cterm=bold
highlight ClaudeFeedback guifg=#fbbf24 guibg=#7c3aed gui=bold ctermbg=93 ctermfg=yellow cterm=bold
highlight ClaudeCancel guifg=#f87171 guibg=#7c3aed gui=bold ctermbg=93 ctermfg=red cterm=bold
highlight ClaudeKey guifg=#fef08a guibg=#7c3aed gui=bold ctermbg=93 ctermfg=229 cterm=bold
highlight ClaudeOriginal guifg=#f38ba8 guibg=#313244 gui=bold ctermbg=237 ctermfg=211 cterm=bold
highlight ClaudeProposed guifg=#a6e3a1 guibg=#313244 gui=bold ctermbg=237 ctermfg=151 cterm=bold

" Tabline: file path + actions (single header row)
set showtabline=2
set tabline=%#ClaudeHeader#\ CLAUDE\ REVIEW\ %#ClaudeFile#│\ ${FILE_PATH}\ %=%#ClaudeKey#Enter\ %#ClaudeApprove#✓Approve\ \ %#ClaudeKey#r\ %#ClaudeFeedback#↻Redo\ \ %#ClaudeKey#q\ %#ClaudeCancel#✗Cancel\ \

" Setup windows after diff opens
autocmd VimEnter * call s:SetupWindows()
function! s:SetupWindows()
    " Left window (window 1) = original
    1wincmd w
    let &l:winbar = '%#ClaudeOriginal#  ← ORIGINAL '
    setlocal nomodifiable
    " Right window (window 2) = proposed, keep focus here
    2wincmd w
    let &l:winbar = '%#ClaudeProposed#  → PROPOSED '
    setlocal nomodifiable
endfunction
VIMSCRIPT

    tmux display-popup -E -w 90% -h 90% \
        nvim -d "$ORIGINAL_FILE" "$PROPOSED_FILE" -S "$vim_script" 2>/dev/null || return 1
}

wait_for_decision() {
    sleep 0.2

    local timeout=120
    local elapsed=0
    while [[ ! -f "$SIGNAL_FILE" ]]; do
        sleep 1
        elapsed=$((elapsed + 1))
        [[ $elapsed -ge $timeout ]] && echo "timeout" && return
    done
    cat "$SIGNAL_FILE"
}

prompt_for_feedback() {
    local feedback_file="$TEMP_DIR/feedback.txt"
    rm -f "$feedback_file"

    # Create a simple script to capture feedback
    local prompt_script="$TEMP_DIR/feedback_prompt.sh"
    cat > "$prompt_script" << 'SCRIPT'
#!/bin/bash
echo ""
echo "  ╭──────────────────────────────────────────────────────────────╮"
echo "  │              What should Claude do differently?              │"
echo "  ╰──────────────────────────────────────────────────────────────╯"
echo ""
read -p "  → " feedback
echo "$feedback" > "$1"
SCRIPT
    chmod +x "$prompt_script"

    tmux display-popup -E -w 70% -h 20% \
        bash "$prompt_script" "$feedback_file" 2>/dev/null || return 1

    if [[ -f "$feedback_file" ]]; then
        cat "$feedback_file"
    fi
}

main() {
    check_requirements || exit 0
    capture_original_file
    create_proposed_file
    open_review || exit 0

    local decision
    decision=$(wait_for_decision)

    case "$decision" in
        approve|timeout)
            exit 0
            ;;
        feedback)
            local feedback
            feedback=$(prompt_for_feedback)
            if [[ -n "$feedback" ]]; then
                echo "User rejected this change with feedback: $feedback" >&2
            else
                echo "User rejected this change. Please try a different approach." >&2
            fi
            exit 2
            ;;
        cancel|*)
            echo "User cancelled this change." >&2
            exit 2
            ;;
    esac
}

main
