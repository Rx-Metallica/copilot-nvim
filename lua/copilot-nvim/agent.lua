local M = {}
local core = require("copilot-nvim")

local agent_buf = nil
local agent_win = nil
local input_buf = nil
local input_win = nil
local term_buf = nil
local term_win = nil

-- Append to agent chat buffer
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

-- Run a shell command in the terminal buffer
function M._run_command(cmd)
  vim.schedule(function()
    if not term_win or not vim.api.nvim_win_is_valid(term_win) then return end
    vim.api.nvim_set_current_win(term_win)
    -- Send command to terminal
    local term_id = vim.b[term_buf].terminal_job_id
    if term_id then
      vim.fn.chansend(term_id, cmd .. "\n")
    end
  end)
end

-- Extract commands from Copilot response
local function extract_commands(text)
  local commands = {}
  for cmd in text:gmatch("```bash\n(.-)\n```") do
    table.insert(commands, cmd)
  end
  -- Also match single line commands like `npm install`
  for cmd in text:gmatch("`([^`]+)`") do
    if cmd:match("^[a-z]") and not cmd:match("%s%s") then
      table.insert(commands, cmd)
    end
  end
  return commands
end

-- Open agent UI
function M.open()
  if agent_win and vim.api.nvim_win_is_valid(agent_win) then
    vim.api.nvim_set_current_win(input_win)
    return
  end

  -- Agent chat buffer (top right)
  agent_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(agent_buf, "filetype", "markdown")
  vim.api.nvim_buf_set_option(agent_buf, "modifiable", false)

  -- Input buffer (middle right)
  input_buf = vim.api.nvim_create_buf(false, true)

  -- Terminal buffer (bottom)
  vim.cmd("botright vsplit")
  agent_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(agent_win, agent_buf)
  vim.api.nvim_win_set_width(agent_win, 55)

  -- Input window below agent
  vim.cmd("belowright split")
  input_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(input_win, input_buf)
  vim.api.nvim_win_set_height(input_win, 3)

  -- Terminal window below input
  vim.cmd("belowright split")
  term_win = vim.api.nvim_get_current_win()
  vim.cmd("terminal")
  term_buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_win_set_height(term_win, 10)

  -- Welcome message
  M._append("# Copilot Agent 🤖")
  M._append("")
  M._append("I can run commands for you!")
  M._append("Try: 'list files in current directory'")
  M._append("Or:  'create a hello.py file'")
  M._append("---")

  -- Keymaps
  vim.keymap.set("i", "<CR>", function()
    M.send()
  end, { buffer = input_buf, desc = "Agent: Send" })

  vim.keymap.set("n", "<CR>", function()
    M.send()
  end, { buffer = input_buf, desc = "Agent: Send" })

  vim.keymap.set("n", "q", function()
    M.close()
  end, { buffer = agent_buf, desc = "Agent: Close" })

  vim.api.nvim_set_current_win(input_win)
  vim.cmd("startinsert")
end

-- Send message to agent
function M.send()
  if not input_buf or not vim.api.nvim_buf_is_valid(input_buf) then return end

  local lines = vim.api.nvim_buf_get_lines(input_buf, 0, -1, false)
  local message = table.concat(lines, "\n"):gsub("^%s+", ""):gsub("%s+$", "")
  if message == "" then return end

  vim.api.nvim_buf_set_lines(input_buf, 0, -1, false, {""})
  M._append("")
  M._append("**You:** " .. message)
  M._append("**Agent:** _thinking..._")

  local system_prompt = [[You are a terminal agent. When the user asks you to do something:
1. Explain what you will do briefly
2. Provide the exact shell command in a ```bash code block
3. Keep responses concise
The user is on Windows so use Windows-compatible commands.]]

  core.request("chat", { message = system_prompt .. "\n\nUser request: " .. message, context = "" }, function(response)
    if not response.success then
      M._append("**Error:** " .. response.error)
      return
    end

    vim.schedule(function()
      -- Remove thinking line
      if agent_buf and vim.api.nvim_buf_is_valid(agent_buf) then
        vim.api.nvim_buf_set_option(agent_buf, "modifiable", true)
        local count = vim.api.nvim_buf_line_count(agent_buf)
        vim.api.nvim_buf_set_lines(agent_buf, count - 1, count, false, {})
        vim.api.nvim_buf_set_option(agent_buf, "modifiable", false)
      end

      M._append("**Agent:** " .. response.result)
      M._append("---")

      -- Auto run extracted commands in terminal
      local commands = extract_commands(response.result)
      if #commands > 0 then
        M._append("_Running command in terminal..._")
        M._run_command(commands[1])
      end
    end)
  end)
end

-- Close agent
function M.close()
  for _, win in ipairs({ agent_win, input_win, term_win }) do
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  agent_buf = nil
  agent_win = nil
  input_buf = nil
  input_win = nil
  term_buf = nil
  term_win = nil
end

-- Setup keymaps
function M.setup()
  vim.keymap.set("n", "<leader>a", function()
    M.open()
  end, { desc = "Copilot: Open agent" })
end

return M