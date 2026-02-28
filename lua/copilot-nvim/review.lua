local M = {}
local core = require("copilot-nvim")

local review_buf = nil
local review_win = nil

-- Open review window
function M._open_window()
  if review_win and vim.api.nvim_win_is_valid(review_win) then
    return
  end

  review_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(review_buf, "Copilot Review")
  vim.api.nvim_buf_set_option(review_buf, "filetype", "markdown")
  vim.api.nvim_buf_set_option(review_buf, "modifiable", false)

  vim.cmd("botright vsplit")
  review_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(review_win, review_buf)
  vim.api.nvim_win_set_width(review_win, 50)

  -- Close with q
  vim.keymap.set("n", "q", function()
    M.close()
  end, { buffer = review_buf, desc = "Copilot: Close review" })
end

-- Write content to review buffer
function M._set_content(lines)
  vim.schedule(function()
    if not review_buf or not vim.api.nvim_buf_is_valid(review_buf) then return end
    vim.api.nvim_buf_set_option(review_buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(review_buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(review_buf, "modifiable", false)
  end)
end

-- Review current buffer
function M.review()
  local bufnr = vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local code = table.concat(lines, "\n")

  if code:gsub("%s+", "") == "" then
    vim.notify("[copilot] Nothing to review!", vim.log.levels.WARN)
    return
  end

  vim.notify("[copilot] Reviewing code...", vim.log.levels.INFO)
  M._open_window()
  M._set_content({ "# Copilot Code Review", "", "⏳ Reviewing `" .. vim.fn.fnamemodify(filename, ":t") .. "`...", "" })

  core.request("review", { code = code, context = filename }, function(response)
    if not response.success then
      M._set_content({ "# Copilot Code Review", "", "❌ Error: " .. response.error })
      return
    end

    local result_lines = { "# Copilot Code Review", "" }
    for _, line in ipairs(vim.split(response.result, "\n")) do
      table.insert(result_lines, line)
    end
    table.insert(result_lines, "")
    table.insert(result_lines, "---")
    table.insert(result_lines, "Press `q` to close")

    M._set_content(result_lines)
    vim.notify("[copilot] Review complete! ✅", vim.log.levels.INFO)
  end)
end

-- Close review window
function M.close()
  if review_win and vim.api.nvim_win_is_valid(review_win) then
    vim.api.nvim_win_close(review_win, true)
  end
  review_win = nil
  review_buf = nil
end

-- Setup autocmd and keymaps
function M.setup()
  -- Manual trigger with <leader>r
  vim.keymap.set("n", "<leader>r", function()
    M.review()
  end, { desc = "Copilot: Review code" })

  -- Auto review on save (with delay to ensure bridge is ready)
  vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = { "*.py", "*.js", "*.ts", "*.lua", "*.go", "*.rs" },
    callback = function()
      vim.defer_fn(function()
        M.review()
      end, 3000)
    end,
  })
end

return M