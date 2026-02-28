local M = {}

local job_id = nil
local pending = {}
local request_id = 0
local is_ready = false

-- Start the Node.js bridge process
function M.setup(opts)
  opts = opts or {}
  local bridge = opts.node_bridge or "D:/copilot-nvim/node/src/index.ts"

  is_ready = false
  job_id = vim.fn.jobstart({"npx", "tsx", bridge}, {
    on_stdout = function(_, data)
      for _, line in ipairs(data) do
        if line ~= "" then
          local ok, response = pcall(vim.json.decode, line)
          if ok and response then
            M._handle_response(response)
          end
        end
      end
    end,
    on_stderr = function(_, data)
      for _, line in ipairs(data) do
        if line ~= "" and not line:match("ExperimentalWarning") and not line:match("Node.js") then
          vim.notify("[copilot-nvim] " .. line, vim.log.levels.WARN)
        end
      end
    end,
    on_exit = function()
      vim.notify("[copilot-nvim] Bridge stopped", vim.log.levels.INFO)
      job_id = nil
      is_ready = false
    end,
    stdout_buffered = false,
  })

  if job_id <= 0 then
    vim.notify("[copilot-nvim] Failed to start bridge!", vim.log.levels.ERROR)
    return
  end

  vim.notify("[copilot-nvim] Bridge started ✅", vim.log.levels.INFO)

  -- Load completions
  local completions = require("copilot-nvim.completions")
  completions.setup()
  completions.enable_auto()

  -- Load chat
  require("copilot-nvim.chat").setup()

  -- Load review
  require("copilot-nvim.review").setup()

  -- Load agent
  require("copilot-nvim.agent").setup()
end

-- Send a request to the Node.js bridge
function M.request(type, data, callback)
  if not job_id then
    vim.notify("[copilot-nvim] Bridge not running!", vim.log.levels.ERROR)
    return
  end

  if not is_ready then
    vim.notify("[copilot-nvim] Copilot not ready yet, please wait...", vim.log.levels.WARN)
    return
  end

  request_id = request_id + 1
  local id = tostring(request_id)
  pending[id] = callback

  local payload = vim.json.encode({ id = id, type = type, data = data })
  vim.fn.chansend(job_id, payload .. "\n")
end

-- Handle responses from the bridge
function M._handle_response(response)
  local id = response.id
  if id == "init" then
    is_ready = true
    vim.notify("[copilot-nvim] Copilot ready 🚀", vim.log.levels.INFO)
    return
  end

  local cb = pending[id]
  if cb then
    pending[id] = nil
    cb(response)
  end
end

-- Stop the bridge
function M.stop()
  if job_id then
    vim.fn.jobstop(job_id)
    job_id = nil
    is_ready = false
  end
end

return M