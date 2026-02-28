local M = {}
local core = require("copilot-nvim")

local agent_buf, agent_win
local input_buf, input_win
local term_buf, term_win
local term_job_id

-- Append text to chat buffer safely
function M._append(text)
  vim.schedule(function()
    if not agent_buf or not vim.api.nvim_buf_is_valid(agent_buf) then return end

    vim.api.nvim_buf_set_option(agent_buf, "modifiable", true)
    local lines = vim.split(text, "\n")
    local count = vim.api.nvim_buf_line_count(agent_buf)
    vim.api.nvim_buf_set_lines(agent_buf, count, -1, false, lines)
    vim.api.nvim_buf_set_option(agent_buf, "modifiable", false)

    if agent_win and vim.api.nvim_win_is_valid(agent_win) then
      vim.api.nvim_win_set_cursor(agent_win, { vim.api.nvim_buf_line_count(agent_buf), 0 })
    end
  end)
end

-- Start proper Neovim terminal
local function start_terminal()
  vim.api.nvim_set_current_win(term_win)
  vim.cmd("terminal cmd.exe")
  term_buf = vim.api.nvim_get_current_buf()
  term_job_id = vim.b.terminal_job_id
end

-- Execute commands with confirmation
local function execute_commands(commands)
  if not term_job_id then
    M._append("Terminal not ready.")
    return
  end

  vim.ui.select({ "Yes", "No" }, {
    prompt = "Execute agent commands?"
  }, function(choice)
    if choice ~= "Yes" then
      M._append("Execution cancelled.")
      return
    end

    for _, cmd in ipairs(commands) do
      M._append("")
      M._append("▶ Running: " .. cmd)
      vim.fn.chansend(term_job_id, cmd .. "\n")
    end
  end)
end

-- Open agent UI
function M.open()
  if agent_win and vim.api.nvim_win_is_valid(agent_win) then
    vim.api.nvim_set_current_win(input_win)
    vim.cmd("startinsert")
    return
  end

  -- Chat buffer
  agent_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(agent_buf, "filetype", "markdown")
  vim.api.nvim_buf_set_option(agent_buf, "modifiable", false)

  -- Input buffer
  input_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(input_buf, "modifiable", true)

  -- Layout
  vim.cmd("botright vsplit")
  agent_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(agent_win, agent_buf)
  vim.api.nvim_win_set_width(agent_win, 60)

  vim.cmd("belowright split")
  input_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(input_win, input_buf)
  vim.api.nvim_win_set_height(input_win, 3)

  vim.cmd("belowright split")
  term_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_height(term_win, 12)

  start_terminal()

  -- Welcome
  M._append("# Copilot Autonomous Agent 🤖")
  M._append("")
  M._append("Describe what you want to do.")
  M._append("Example: create a new folder called test")
  M._append("---")

  -- Keymaps
  vim.keymap.set("i", "<CR>", function() M.send() end, { buffer = input_buf })
  vim.keymap.set("n", "<CR>", function() M.send() end, { buffer = input_buf })
  vim.keymap.set("n", "q", function() M.close() end, { buffer = agent_buf })

  vim.api.nvim_set_current_win(input_win)
  vim.cmd("startinsert")
end

-- Send to Copilot
function M.send()
  if not input_buf or not vim.api.nvim_buf_is_valid(input_buf) then return end

  local lines = vim.api.nvim_buf_get_lines(input_buf, 0, -1, false)
  local message = table.concat(lines, "\n"):gsub("^%s+", ""):gsub("%s+$", "")
  if message == "" then return end

  vim.api.nvim_buf_set_lines(input_buf, 0, -1, false, { "" })

  M._append("")
  M._append("**You:** " .. message)
  M._append("**Agent:** Thinking...")

  local system_prompt = [[
You are a Windows CMD automation agent.

When given a task:
1. Brief explanation
2. Return JSON only in this format:

{
  "explanation": "short explanation",
  "commands": ["command1", "command2"]
}

Rules:
- Only valid Windows CMD commands
- No markdown
- No extra commentary
]]

  core.request("chat", {
    message = system_prompt .. "\n\nUser request: " .. message,
    context = ""
  }, function(response)

    if not response.success then
      M._append("Error: " .. response.error)
      return
    end

    local ok, data = pcall(vim.fn.json_decode, response.result)

    if not ok or not data.commands then
      M._append("Invalid agent response.")
      M._append(response.result)
      return
    end

    -- Remove thinking line
    vim.api.nvim_buf_set_option(agent_buf, "modifiable", true)
    local count = vim.api.nvim_buf_line_count(agent_buf)
    vim.api.nvim_buf_set_lines(agent_buf, count - 1, count, false, {})
    vim.api.nvim_buf_set_option(agent_buf, "modifiable", false)

    M._append("**Agent:** " .. data.explanation)
    M._append("---")

    execute_commands(data.commands)

    vim.api.nvim_set_current_win(input_win)
    vim.cmd("startinsert")
  end)
end

-- Close UI
function M.close()
  for _, win in ipairs({ agent_win, input_win, term_win }) do
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  agent_buf, agent_win = nil, nil
  input_buf, input_win = nil, nil
  term_buf, term_win = nil, nil
  term_job_id = nil
end

-- Setup keymap
function M.setup()
  vim.keymap.set("n", "<leader>a", function()
    M.open()
  end, { desc = "Copilot Autonomous Agent" })
end

return M