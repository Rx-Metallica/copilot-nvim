local M = {}
local core = require("copilot-nvim")

local chat_buf = nil
local chat_win = nil
local input_buf = nil
local input_win = nil

-- Create the chat UI (split window)
function M.open()
  if chat_win and vim.api.nvim_win_is_valid(chat_win) then
    vim.api.nvim_set_current_win(chat_win)
    return
  end

  -- Create chat buffer
  chat_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(chat_buf, "Copilot Chat")
  vim.api.nvim_buf_set_option(chat_buf, "filetype", "markdown")
  vim.api.nvim_buf_set_option(chat_buf, "modifiable", false)

  -- Create input buffer
  input_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(input_buf, "Copilot Input")

  -- Open chat window on the right
  vim.cmd("botright vsplit")
  chat_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(chat_win, chat_buf)
  vim.api.nvim_win_set_width(chat_win, 50)

  -- Open input window below chat
  vim.cmd("belowright split")
  input_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(input_win, input_buf)
  vim.api.nvim_win_set_height(input_win, 3)

  -- Welcome message
  M._append("# Copilot Chat\n")
  M._append("Ask anything about your code!\n")
  M._append("---\n")

  -- Keymaps for input buffer
  vim.keymap.set("i", "<CR>", function()
    M.send()
  end, { buffer = input_buf, desc = "Copilot: Send message" })

  vim.keymap.set("n", "<CR>", function()
    M.send()
  end, { buffer = input_buf, desc = "Copilot: Send message" })

  vim.keymap.set("n", "q", function()
    M.close()
  end, { buffer = chat_buf, desc = "Copilot: Close chat" })

  -- Focus input
  vim.api.nvim_set_current_win(input_win)
  vim.cmd("startinsert")
end

-- Append text to chat buffer
function M._append(text)
  vim.schedule(function()
    if not chat_buf or not vim.api.nvim_buf_is_valid(chat_buf) then return end
    vim.api.nvim_buf_set_option(chat_buf, "modifiable", true)
    local lines = vim.split(text, "\n")
    local line_count = vim.api.nvim_buf_line_count(chat_buf)
    vim.api.nvim_buf_set_lines(chat_buf, line_count, -1, false, lines)
    vim.api.nvim_buf_set_option(chat_buf, "modifiable", false)
    -- Scroll to bottom
    if chat_win and vim.api.nvim_win_is_valid(chat_win) then
      vim.api.nvim_win_set_cursor(chat_win, { vim.api.nvim_buf_line_count(chat_buf), 0 })
    end
  end)
end

-- Send message from input buffer
function M.send()
  if not input_buf or not vim.api.nvim_buf_is_valid(input_buf) then return end

  local lines = vim.api.nvim_buf_get_lines(input_buf, 0, -1, false)
  local message = table.concat(lines, "\n"):gsub("^%s+", ""):gsub("%s+$", "")

  if message == "" then return end

  -- Clear input
  vim.api.nvim_buf_set_lines(input_buf, 0, -1, false, {""})

  -- Show user message in chat
  M._append("\n**You:** " .. message)
  M._append("\n**Copilot:** _thinking..._\n")

  -- Get current file context
  local context = ""
  local prev_win = vim.fn.winnr("#")
  if prev_win > 0 then
    local prev_buf = vim.api.nvim_win_get_buf(vim.fn.win_getid(prev_win))
    local file_lines = vim.api.nvim_buf_get_lines(prev_buf, 0, -1, false)
    context = table.concat(file_lines, "\n")
  end

  core.request("chat", { message = message, context = context }, function(response)
    if not response.success then
      M._append("\n**Error:** " .. response.error .. "\n")
      return
    end
    -- Remove "thinking" line and add real response
    vim.schedule(function()
      if chat_buf and vim.api.nvim_buf_is_valid(chat_buf) then
        vim.api.nvim_buf_set_option(chat_buf, "modifiable", true)
        local count = vim.api.nvim_buf_line_count(chat_buf)
        vim.api.nvim_buf_set_lines(chat_buf, count - 2, count, false, {})
        vim.api.nvim_buf_set_option(chat_buf, "modifiable", false)
      end
      M._append("\n**Copilot:** " .. response.result .. "\n")
      M._append("---\n")
    end)
  end)
end

-- Close chat
function M.close()
  if chat_win and vim.api.nvim_win_is_valid(chat_win) then
    vim.api.nvim_win_close(chat_win, true)
  end
  if input_win and vim.api.nvim_win_is_valid(input_win) then
    vim.api.nvim_win_close(input_win, true)
  end
  chat_buf = nil
  chat_win = nil
  input_buf = nil
  input_win = nil
end

-- Setup keymaps
function M.setup()
  -- Open chat with Ctrl+P
  vim.keymap.set("n", "<C-p>", function()
    M.open()
  end, { desc = "Copilot: Open chat" })
end

return M