local config = require("procman.config")
local process = require("procman.process")
local commands = require("procman.commands")
local memory = require("procman.memory")

local M = {}

local poll_timer = nil

local function do_poll()
  local any_running = false
  for _, name in ipairs(process.list()) do
    local svc = process.get(name)
    if svc.status == "running" then
      any_running = true
      break
    end
  end
  if not any_running then
    return
  end
  memory.snapshot(function(tree, err)
    if tree then
      process.refresh_memory(tree)
    elseif err then
      vim.notify("[procman] " .. err, vim.log.levels.WARN, { once = true })
    end
  end)
end

function M.poll_now()
  do_poll()
end

local function start_polling()
  if poll_timer then
    return
  end
  poll_timer = vim.loop.new_timer()
  poll_timer:start(
    config.options.poll_interval,
    config.options.poll_interval,
    vim.schedule_wrap(do_poll)
  )
end

local function register_autocmds()
  local group = vim.api.nvim_create_augroup("ProcManRefresh", { clear = true })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "ProcManUpdate",
    callback = function(args)
      require("procman.ui.panel").refresh()
      local name = args.data and args.data.name
      if name then
        require("procman.ui.log").refresh_title(name)
      end
    end,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      process.stop_all()
    end,
  })
end

function M.setup(opts)
  config.setup(opts)
  process.setup_services()
  commands.setup()
  register_autocmds()
  start_polling()

  for _, name in ipairs(process.list()) do
    local svc = process.get(name)
    if svc.autostart then
      process.start(name)
    end
  end
end

M.start = process.start
M.stop = process.stop
M.restart = process.restart
M.start_all = process.start_all
M.stop_all = process.stop_all
M.list = process.list
M.get = process.get
M.reload = process.reload
M.open_panel = function() require("procman.ui.panel").open() end
M.toggle_panel = function() require("procman.ui.panel").toggle() end
M.open_logs = function(name) require("procman.ui.log").open(name) end

return M
