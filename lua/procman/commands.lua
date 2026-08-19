local process = require("procman.process")
local config = require("procman.config")
local discover = require("procman.discover")
local project_config = require("procman.project_config")

local M = {}

local function complete_service_names(arg_lead)
  local names = process.list()
  if arg_lead == "" then
    return names
  end
  return vim.tbl_filter(function(n)
    return n:sub(1, #arg_lead) == arg_lead
  end, names)
end

local function ask_sequence(steps, on_done)
  local answers = {}
  local function ask_step(i)
    if i > #steps then
      on_done(answers)
      return
    end
    vim.ui.input({ prompt = steps[i].prompt }, function(value)
      value = value or ""
      if steps[i].validate then
        local ok, err = steps[i].validate(value)
        if not ok then
          if err then
            vim.notify("[procman] " .. err, vim.log.levels.WARN)
          end
          return
        end
      end
      answers[i] = value
      ask_step(i + 1)
    end)
  end
  ask_step(1)
end

local function not_empty(err_msg)
  return function(value)
    if value == "" then
      return false, err_msg
    end
    return true
  end
end

function M.setup()
  local panel = require("procman.ui.panel")
  local log = require("procman.ui.log")

  vim.api.nvim_create_user_command("ProcManOpen", function()
    panel.open()
  end, { desc = "Open the Procman process panel" })

  vim.api.nvim_create_user_command("ProcManToggle", function()
    panel.toggle()
  end, { desc = "Toggle the Procman process panel" })

  vim.api.nvim_create_user_command("ProcManClose", function()
    panel.close()
  end, { desc = "Close the Procman process panel" })

  vim.api.nvim_create_user_command("ProcManStart", function(cmd_opts)
    if cmd_opts.args == "" then
      vim.notify("[procman] usage: :ProcManStart <name>", vim.log.levels.WARN)
      return
    end
    process.start(cmd_opts.args)
  end, {
    nargs = 1,
    complete = function(arg_lead) return complete_service_names(arg_lead) end,
    desc = "Start a service",
  })

  vim.api.nvim_create_user_command("ProcManStop", function(cmd_opts)
    if cmd_opts.args == "" then
      vim.notify("[procman] usage: :ProcManStop <name>", vim.log.levels.WARN)
      return
    end
    process.stop(cmd_opts.args)
  end, {
    nargs = 1,
    complete = function(arg_lead) return complete_service_names(arg_lead) end,
    desc = "Stop a service",
  })

  vim.api.nvim_create_user_command("ProcManRestart", function(cmd_opts)
    if cmd_opts.args == "" then
      vim.notify("[procman] usage: :ProcManRestart <name>", vim.log.levels.WARN)
      return
    end
    process.restart(cmd_opts.args)
  end, {
    nargs = 1,
    complete = function(arg_lead) return complete_service_names(arg_lead) end,
    desc = "Restart a service",
  })

  vim.api.nvim_create_user_command("ProcManStartAll", function()
    process.start_all()
  end, { desc = "Start all services" })

  vim.api.nvim_create_user_command("ProcManStopAll", function()
    process.stop_all()
  end, { desc = "Stop all services" })

  vim.api.nvim_create_user_command("ProcManLogs", function(cmd_opts)
    if cmd_opts.args == "" then
      vim.notify("[procman] usage: :ProcManLogs <name>", vim.log.levels.WARN)
      return
    end
    log.open(cmd_opts.args)
  end, {
    nargs = 1,
    complete = function(arg_lead) return complete_service_names(arg_lead) end,
    desc = "Open a service's logs in a floating window",
  })

  vim.api.nvim_create_user_command("ProcManEdit", function()
    local root = config.options.root
    local path = project_config.path(root)

    if vim.fn.filereadable(path) == 0 then
      local discovered = {}
      if config.options.auto_discover then
        discovered = discover.discover(root, config.options.discover_depth, config.options.discover_ignore)
      end
      vim.fn.writefile(vim.split(project_config.template(root, discovered), "\n"), path)
    end

    vim.cmd.edit(vim.fn.fnameescape(path))

    local group = vim.api.nvim_create_augroup("ProcManEditReload", { clear = false })
    vim.api.nvim_create_autocmd("BufWritePost", {
      group = group,
      buffer = vim.api.nvim_get_current_buf(),
      callback = function()
        process.reload()
        vim.notify("[procman] services reloaded from " .. project_config.filename, vim.log.levels.INFO)
      end,
    })
  end, { desc = "Create/edit this project's " .. project_config.filename .. " and reload on save" })

  vim.api.nvim_create_user_command("ProcManAdd", function()
    local root = config.options.root

    ask_sequence({
      { prompt = "Service name: ", validate = not_empty("empty name, cancelled") },
      { prompt = "Command (e.g. npm run build): ", validate = not_empty("empty command, cancelled") },
      { prompt = "cwd (relative to root, empty = root): " },
      { prompt = "kind (dotnet/node/rust/go/custom) [custom]: " },
    }, function(answers)
      local name, cmd, cwd, kind = answers[1], answers[2], answers[3], answers[4]
      kind = kind ~= "" and kind or "custom"

      local discovered = {}
      if config.options.auto_discover then
        discovered = discover.discover(root, config.options.discover_depth, config.options.discover_ignore)
      end

      local ok, err = project_config.add_service(root, name, { cmd = cmd, cwd = cwd, kind = kind }, discovered)
      if not ok then
        vim.notify("[procman] " .. err, vim.log.levels.ERROR)
        return
      end

      process.reload()
      vim.notify(
        ("[procman] service '%s' added to %s"):format(name, project_config.filename),
        vim.log.levels.INFO
      )
    end)
  end, { desc = "Create a custom command (via prompt) and add it to " .. project_config.filename })

  vim.api.nvim_create_user_command("ProcManReload", function()
    process.reload()
    vim.notify("[procman] services reloaded", vim.log.levels.INFO)
  end, { desc = "Reload discovery + " .. project_config.filename .. " + setup() services" })
end

return M
