-- claude-review.lua
-- Neovim plugin for Claude Code diff review workflow
--
-- Provides keybindings to approve or reject changes shown in vimdiff.
-- Only active when g:claude_review_signal is set by the diff-review hook.

local function write_signal(decision)
    local signal_file = vim.g.claude_review_signal
    if not signal_file then
        vim.notify("No claude review session active", vim.log.levels.WARN)
        return false
    end

    local f = io.open(signal_file, "w")
    if not f then
        vim.notify("Failed to write signal file: " .. signal_file, vim.log.levels.ERROR)
        return false
    end

    f:write(decision)
    f:close()
    return true
end

local function approve_change()
    local file = vim.g.claude_review_file or "unknown"
    if write_signal("approve") then
        vim.notify("✓ Approved: " .. file, vim.log.levels.INFO)
        -- Small delay to show message before closing
        vim.defer_fn(function()
            vim.cmd("qa!")
        end, 200)
    end
end

local function reject_change()
    local file = vim.g.claude_review_file or "unknown"
    if write_signal("reject") then
        vim.notify("✗ Rejected: " .. file, vim.log.levels.WARN)
        -- Small delay to show message before closing
        vim.defer_fn(function()
            vim.cmd("qa!")
        end, 200)
    end
end

-- Set up keymaps (global, but only functional when in review session)
vim.keymap.set("n", "<leader>ca", approve_change, {
    desc = "Claude: Approve change",
    silent = true,
})

vim.keymap.set("n", "<leader>cr", reject_change, {
    desc = "Claude: Reject change",
    silent = true,
})

-- Also provide commands for discoverability
vim.api.nvim_create_user_command("ClaudeApprove", approve_change, {
    desc = "Approve the current Claude Code change",
})

vim.api.nvim_create_user_command("ClaudeReject", reject_change, {
    desc = "Reject the current Claude Code change",
})
