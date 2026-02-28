local M = {}
local core = require("copilot-nvim")

local ns = vim.api.nvim_create_namespace("copilot_completion")

-- Extract clean code from markdown code blocks
local function extract_code(text)
  local code = text:match("```%w*\n(.-)\n```")
  if code then return code end
  return text
end

function M.get_completion()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local prompt = table.concat(lines, "\n")
  local filetype = vim.bo.filetype

  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  core.request("complete", { prompt = prompt, language = filetype }, function(response)
    if not response.success then
      vim.notify("[copilot] " .. response.error, vim.log.levels.ERROR)
      return
    end

    local result = extract_code(response.result or "")
    local first_line = vim.split(result, "\n")[1] or ""
    first_line = first_line:gsub("^%s+", "")

    if first_line == "" then
      vim.notify("[copilot] No completion", vim.log.levels.WARN)
      return
    end

    vim.schedule(function()
      vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
        virt_text = {{ " " .. first_line, "Comment" }},
        virt_text_pos = "eol",
      })
      vim.notify("[copilot] Suggestion ready — Tab to accept", vim.log.levels.INFO)
    end)
  end)
end

-- Accept the completion by pressing Tab
function M.accept()
  local bufnr = vim.api.nvim_get_current_buf()
  local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true })

  if #marks == 0 then return false end

  local mark = marks[1]
  local row = mark[2]
  local virt_text = mark[4].virt_text

  if not virt_text or #virt_text == 0 then return false end

  local completion = virt_text[1][1]:gsub("^ ", "")

  vim.schedule(function()
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
    vim.api.nvim_buf_set_lines(bufnr, row, row + 1, false, { line .. completion })
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    vim.api.nvim_win_set_cursor(0, { row + 1, #line + #completion })
  end)

  return true
end

-- Setup keymaps
function M.setup()
  vim.keymap.set("i", "<C-g>", function()
    M.get_completion()
  end, { desc = "Copilot: Get completion" })

  vim.keymap.set("i", "<Tab>", function()
    if not M.accept() then
      vim.api.nvim_feedkeys("\t", "n", false)
    end
  end, { desc = "Copilot: Accept completion" })

  vim.keymap.set("i", "<Esc>", function()
    local bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
  end, { desc = "Copilot: Dismiss completion" })
end

-- Auto trigger completion while typing (debounced)
function M.enable_auto()
  local timer = vim.loop.new_timer()

  vim.api.nvim_create_autocmd("TextChangedI", {
    pattern = "*",
    callback = function()
      timer:stop()
      timer:start(800, 0, vim.schedule_wrap(function()
        local line = vim.api.nvim_get_current_line()
        if #line >= 3 then
          M.get_completion()
        end
      end))
    end,
  })
end

return M