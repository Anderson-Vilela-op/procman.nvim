local config = require("procman.config")
local discover = require("procman.discover")
local project_config = require("procman.project_config")

local M = {}

M.services = {}

local function emit_update(name)
  vim.api.nvim_exec_autocmds("User", {
    pattern = "ProcManUpdate",
    data = { name = name },
  })
end

local function resolve_cwd(root, cwd)
  if not cwd or cwd == "" then
    return root
  end
  if cwd:sub(1, 1) == "/" then
    return cwd
  end
  return root .. "/" .. cwd
end

function M.setup_services()
  local opts = config.options
  local discovered = {}
  if opts.auto_discover then
    discovered = discover.discover(opts.root, opts.discover_depth, opts.discover_ignore)
  end

  local project_services = project_config.load(opts.root)

  local nvim_project = config.project_for_root(opts.root)
  local nvim_project_services = (nvim_project and nvim_project.services) or {}

  local merged = vim.tbl_deep_extend(
    "force",
    discovered,
    project_services,
    nvim_project_services,
    opts.services or {}
  )

  for name, cfg in pairs(merged) do
    local existing = M.services[name]
    M.services[name] = {
      name = name,
      cmd = cfg.cmd,
      cwd = resolve_cwd(opts.root, cfg.cwd),
      env = cfg.env,
      kind = cfg.kind,
      autostart = cfg.autostart,
      status = existing and existing.status or "stopped",
      job_id = existing and existing.job_id,
      pid = existing and existing.pid,
      exit_code = existing and existing.exit_code,
      bufnr = existing and existing.bufnr,
      rss_kb = existing and existing.rss_kb or 0,
      manual_stop = false,
      pending_restart = false,
      started_at = existing and existing.started_at,
    }
  end
end

function M.reload()
  M.setup_services()
  emit_update(nil)
end

function M.list()
  local names = vim.tbl_keys(M.services)
  table.sort(names)
  return names
end

function M.get(name)
  return M.services[name]
end

local function ensure_buffer(svc)
  if svc.bufnr and vim.api.nvim_buf_is_valid(svc.bufnr) then
    return svc.bufnr
  end
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].filetype = "procman-log"
  vim.api.nvim_buf_set_name(bufnr, "procman://" .. svc.name .. "/" .. bufnr)
  svc.bufnr = bufnr
  return bufnr
end

local function append_log(svc, lines)
  if not lines or #lines == 0 then
    return
  end
  local bufnr = ensure_buffer(svc)
  local max_lines = config.options.log_max_lines

  vim.bo[bufnr].modifiable = true
  local last = vim.api.nvim_buf_line_count(bufnr)
  local start = last
  if start == 1 and vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] == "" then
    start = 0
  end
  vim.api.nvim_buf_set_lines(bufnr, start, -1, false, lines)

  local count = vim.api.nvim_buf_line_count(bufnr)
  if count > max_lines then
    vim.api.nvim_buf_set_lines(bufnr, 0, count - max_lines, false, {})
  end
  vim.bo[bufnr].modifiable = false

  for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    pcall(vim.api.nvim_win_set_cursor, win, { line_count, 0 })
  end
end

function M.start(name)
  local svc = M.services[name]
  if not svc then
    vim.notify("[procman] unknown service: " .. name, vim.log.levels.ERROR)
    return
  end
  if svc.status == "running" or svc.status == "starting" then
    return
  end

  ensure_buffer(svc)
  vim.bo[svc.bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(svc.bufnr, 0, -1, false, { ("-- starting '%s' --"):format(name) })
  vim.bo[svc.bufnr].modifiable = false

  svc.status = "starting"
  svc.manual_stop = false
  svc.exit_code = nil
  emit_update(name)

  local jobstart_ok, job_id = pcall(vim.fn.jobstart, svc.cmd, {
    cwd = svc.cwd,
    env = svc.env,
    stdout_buffered = false,
    stderr_buffered = false,
    on_stdout = function(_, data)
      append_log(svc, vim.tbl_filter(function(l) return l ~= "" end, data))
    end,
    on_stderr = function(_, data)
      append_log(svc, vim.tbl_filter(function(l) return l ~= "" end, data))
    end,
    on_exit = function(_, code)
      svc.status = (code == 0 or svc.manual_stop) and "stopped" or "failed"
      svc.exit_code = code
      svc.job_id = nil
      svc.pid = nil
      svc.rss_kb = 0
      append_log(svc, { ("-- process exited (exit=%d) --"):format(code) })

      if svc.pending_restart then
        svc.pending_restart = false
        M.start(name)
      else
        emit_update(name)
      end
    end,
  })

  if not jobstart_ok then
    svc.status = "failed"
    append_log(svc, { ("-- failed to start process: %s --"):format(job_id) })
    emit_update(name)
    return
  end

  if job_id <= 0 then
    svc.status = "failed"
    append_log(svc, { "-- failed to start process (invalid command or nonexistent cwd) --" })
    emit_update(name)
    return
  end

  svc.job_id = job_id
  svc.pid = vim.fn.jobpid(job_id)
  svc.status = "running"
  svc.started_at = os.time()
  emit_update(name)
end

function M.stop(name)
  local svc = M.services[name]
  if not svc or not svc.job_id then
    return
  end
  svc.manual_stop = true
  vim.fn.jobstop(svc.job_id)
end

function M.restart(name)
  local svc = M.services[name]
  if not svc then
    return
  end
  if svc.job_id then
    svc.manual_stop = true
    svc.pending_restart = true
    vim.fn.jobstop(svc.job_id)
  else
    M.start(name)
  end
end

function M.start_all()
  for _, name in ipairs(M.list()) do
    M.start(name)
  end
end

function M.stop_all()
  for _, name in ipairs(M.list()) do
    M.stop(name)
  end
end

function M.refresh_memory(tree)
  local memory = require("procman.memory")
  local children = memory.children_by_ppid(tree)
  local changed = false
  for _, svc in pairs(M.services) do
    if svc.status == "running" and svc.pid then
      local kb = memory.total_rss_kb(tree, svc.pid, children)
      if kb ~= svc.rss_kb then
        svc.rss_kb = kb
        changed = true
      end
    end
  end
  if changed then
    emit_update(nil)
  end
end

return M
