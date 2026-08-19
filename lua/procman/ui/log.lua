local config = require("procman.config")
local process = require("procman.process")

local M = {}

local open_wins = {}

local function setup_keymaps(name, bufnr)
  local km = config.options.log_keymaps
  local opts = { buffer = bufnr, nowait = true, silent = true }

  vim.keymap.set("n", km.close, function()
    M.close(name)
  end, opts)

  vim.keymap.set("n", km.stop, function()
    process.stop(name)
  end, opts)

  vim.keymap.set("n", km.restart, function()
    process.restart(name)
  end, opts)

  vim.keymap.set("n", km.scroll_end, function()
    vim.cmd("normal! G")
  end, opts)
end

function M.open(name)
  local svc = process.get(name)
  if not svc then
    vim.notify("[procman] unknown service: " .. name, vim.log.levels.ERROR)
    return
  end

  local existing = open_wins[name]
  if existing and vim.api.nvim_win_is_valid(existing) then
    vim.api.nvim_set_current_win(existing)
    return
  end

  if not (svc.bufnr and vim.api.nvim_buf_is_valid(svc.bufnr)) then
    svc.bufnr = vim.api.nvim_create_buf(false, true)
    vim.bo[svc.bufnr].buftype = "nofile"
    vim.bo[svc.bufnr].filetype = "procman-log"
    vim.api.nvim_buf_set_lines(svc.bufnr, 0, -1, false, { ("(no logs for '%s' yet)"):format(name) })
  end

  local lw = config.options.log_window
  local width = math.floor(vim.o.columns * lw.width)
  local height = math.floor(vim.o.lines * lw.height)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local winnr = vim.api.nvim_open_win(svc.bufnr, true, {
    relative = lw.relative,
    width = width,
    height = height,
    row = row,
    col = col,
    border = lw.border,
    title = string.format(" %s [%s] ", name, svc.status),
    title_pos = "center",
    style = "minimal",
  })

  vim.wo[winnr].wrap = true
  vim.wo[winnr].cursorline = false
  vim.cmd("normal! G")

  setup_keymaps(name, svc.bufnr)
  open_wins[name] = winnr

  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(winnr),
    once = true,
    callback = function()
      open_wins[name] = nil
    end,
  })
end

function M.close(name)
  local winnr = open_wins[name]
  if winnr and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_win_close(winnr, true)
  end
  open_wins[name] = nil
end

function M.refresh_title(name)
  local winnr = open_wins[name]
  if not (winnr and vim.api.nvim_win_is_valid(winnr)) then
    return
  end
  local svc = process.get(name)
  if not svc then
    return
  end
  vim.api.nvim_win_set_config(winnr, {
    title = string.format(" %s [%s] ", name, svc.status),
    title_pos = "center",
  })
end

return M
