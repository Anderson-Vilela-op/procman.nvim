local config = require("procman.config")
local process = require("procman.process")

local M = {}

local bufnr = nil
local winnr = nil
local line_to_name = {}
local line_to_kind = {}
local collapsed_kinds = {}
local hidden = {}
local show_hidden = false
local ns = vim.api.nvim_create_namespace("procman_panel")

local STATUS_HL = {
  running = "ProcManRunning",
  starting = "ProcManStarting",
  stopped = "ProcManStopped",
  failed = "ProcManFailed",
}

local KIND_LABELS = {
  dotnet = ".NET",
  node = "Node/React",
  rust = "Rust",
  go = "Go",
  custom = "Custom",
}

local function setup_highlights()
  vim.api.nvim_set_hl(0, "ProcManRunning", { fg = "#a6e3a1", default = true })
  vim.api.nvim_set_hl(0, "ProcManStarting", { fg = "#f9e2af", default = true })
  vim.api.nvim_set_hl(0, "ProcManStopped", { fg = "#6c7086", default = true })
  vim.api.nvim_set_hl(0, "ProcManFailed", { fg = "#f38ba8", default = true })
  vim.api.nvim_set_hl(0, "ProcManTitle", { fg = "#89b4fa", bold = true, default = true })
  vim.api.nvim_set_hl(0, "ProcManGroup", { fg = "#cba6f7", bold = true, default = true })
  vim.api.nvim_set_hl(0, "ProcManHidden", { fg = "#45475a", italic = true, default = true })
end

local function is_open()
  return winnr ~= nil and vim.api.nvim_win_is_valid(winnr)
end

local function kind_of(svc)
  return (svc.kind and svc.kind ~= "") and svc.kind or "custom"
end

local function label_for_kind(kind)
  return KIND_LABELS[kind] or (kind:sub(1, 1):upper() .. kind:sub(2))
end

local function group_services()
  local groups = {}
  local order = {}
  for _, name in ipairs(process.list()) do
    local svc = process.get(name)
    local kind = kind_of(svc)
    if not groups[kind] then
      groups[kind] = {}
      table.insert(order, kind)
    end
    table.insert(groups[kind], name)
  end
  table.sort(order)
  return groups, order
end

local function format_service_line(name, marked_hidden)
  local icons = config.options.panel.icons
  local svc = process.get(name)
  local icon = icons[svc.status] or "?"
  local mem = svc.status == "running" and require("procman.memory").format_kb(svc.rss_kb) or "-"
  if marked_hidden then
    return string.format("    %s %-18s %-9s %-8s (hidden)", icon, name, svc.status, mem)
  end
  return string.format("    %s %-18s %-9s %s", icon, name, svc.status, mem)
end

local function prune_hidden(groups)
  local known = {}
  for _, names in pairs(groups) do
    for _, name in ipairs(names) do
      known[name] = true
    end
  end
  for name in pairs(hidden) do
    if not known[name] then
      hidden[name] = nil
    end
  end
end

local function render()
  if not (bufnr and vim.api.nvim_buf_is_valid(bufnr)) then
    return
  end
  local groups, order = group_services()
  prune_hidden(groups)

  local lines = { " Procman ", "" }
  line_to_name = {}
  line_to_kind = {}
  local hidden_count = 0

  if #order == 0 then
    table.insert(lines, "  (no services configured/discovered)")
  end

  for _, kind in ipairs(order) do
    local names = groups[kind]
    local visible_names, hidden_names = {}, {}
    for _, name in ipairs(names) do
      if hidden[name] then
        hidden_count = hidden_count + 1
        table.insert(hidden_names, name)
      else
        table.insert(visible_names, name)
      end
    end

    if #visible_names > 0 or (show_hidden and #hidden_names > 0) then
      local collapsed = collapsed_kinds[kind]
      local arrow = collapsed and "▸" or "▾"
      table.insert(lines, string.format("  %s %s (%d)", arrow, label_for_kind(kind), #names))
      line_to_kind[#lines] = kind

      if not collapsed then
        for _, name in ipairs(visible_names) do
          table.insert(lines, format_service_line(name, false))
          line_to_name[#lines] = name
        end
        if show_hidden then
          for _, name in ipairs(hidden_names) do
            table.insert(lines, format_service_line(name, true))
            line_to_name[#lines] = name
          end
        end
      end
    end
  end

  table.insert(lines, "")
  local footer = " [s]tart [x]stop [r]estart [S]tart-all [X]stop-all <CR>/za group|logs [a]dd [H]ide"
  if hidden_count > 0 then
    footer = footer .. string.format(" [E] %d hidden", hidden_count)
  end
  table.insert(lines, footer)

  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = false

  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  vim.api.nvim_buf_set_extmark(bufnr, ns, 0, 0, { end_col = #lines[1], hl_group = "ProcManTitle" })
  for lnum, _ in pairs(line_to_kind) do
    vim.api.nvim_buf_set_extmark(bufnr, ns, lnum - 1, 0, { end_line = lnum - 1, end_col = #lines[lnum], hl_group = "ProcManGroup" })
  end
  for lnum, name in pairs(line_to_name) do
    local hl
    if hidden[name] then
      hl = "ProcManHidden"
    else
      local svc = process.get(name)
      hl = STATUS_HL[svc.status]
    end
    if hl then
      vim.api.nvim_buf_set_extmark(bufnr, ns, lnum - 1, 0, { end_line = lnum - 1, end_col = #lines[lnum], hl_group = hl })
    end
  end
end

local function current_service_name()
  local line = vim.api.nvim_win_get_cursor(winnr)[1]
  return line_to_name[line]
end

local function current_kind()
  local line = vim.api.nvim_win_get_cursor(winnr)[1]
  if line_to_kind[line] then
    return line_to_kind[line]
  end
  local name = line_to_name[line]
  if name then
    local svc = process.get(name)
    return svc and kind_of(svc)
  end
  return nil
end

local function toggle_collapsed(kind)
  collapsed_kinds[kind] = not collapsed_kinds[kind]
  render()
end

local function setup_keymaps()
  local km = config.options.panel_keymaps
  local opts = { buffer = bufnr, nowait = true, silent = true }

  vim.keymap.set("n", km.start, function()
    local name = current_service_name()
    if name then process.start(name) end
  end, opts)

  vim.keymap.set("n", km.stop, function()
    local name = current_service_name()
    if name then process.stop(name) end
  end, opts)

  vim.keymap.set("n", km.restart, function()
    local name = current_service_name()
    if name then process.restart(name) end
  end, opts)

  vim.keymap.set("n", km.start_all, function()
    process.start_all()
  end, opts)

  vim.keymap.set("n", km.stop_all, function()
    process.stop_all()
  end, opts)

  vim.keymap.set("n", km.logs, function()
    local name = current_service_name()
    if name then
      require("procman.ui.log").open(name)
      return
    end
    local line = vim.api.nvim_win_get_cursor(winnr)[1]
    local kind = line_to_kind[line]
    if kind then
      toggle_collapsed(kind)
    end
  end, opts)

  vim.keymap.set("n", km.close, function()
    M.close()
  end, opts)

  vim.keymap.set("n", km.refresh, function()
    require("procman").poll_now()
  end, opts)

  vim.keymap.set("n", km.toggle_group, function()
    local kind = current_kind()
    if kind then
      toggle_collapsed(kind)
    end
  end, opts)

  vim.keymap.set("n", km.add, function()
    vim.cmd("ProcManAdd")
  end, opts)

  vim.keymap.set("n", km.hide, function()
    local name = current_service_name()
    if not name then
      return
    end
    if hidden[name] then
      hidden[name] = nil
    else
      hidden[name] = true
    end
    render()
  end, opts)

  vim.keymap.set("n", km.show_hidden, function()
    show_hidden = not show_hidden
    render()
  end, opts)
end

function M.open()
  setup_highlights()

  if not (bufnr and vim.api.nvim_buf_is_valid(bufnr)) then
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.bo[bufnr].buftype = "nofile"
    vim.bo[bufnr].bufhidden = "hide"
    vim.bo[bufnr].swapfile = false
    vim.bo[bufnr].filetype = "procman-panel"
    vim.api.nvim_buf_set_name(bufnr, "procman://panel")
    setup_keymaps()
  end

  if is_open() then
    render()
    return
  end

  local p = config.options.panel
  local split_cmd
  if p.position == "left" then
    split_cmd = "topleft vsplit"
  elseif p.position == "right" then
    split_cmd = "botright vsplit"
  elseif p.position == "top" then
    split_cmd = "topleft split"
  else
    split_cmd = "botright split"
  end

  vim.cmd(split_cmd)
  winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(winnr, bufnr)

  if p.position == "left" or p.position == "right" then
    vim.api.nvim_win_set_width(winnr, p.width)
  else
    vim.api.nvim_win_set_height(winnr, p.height)
  end

  vim.wo[winnr].number = false
  vim.wo[winnr].relativenumber = false
  vim.wo[winnr].wrap = false
  vim.wo[winnr].cursorline = true
  vim.wo[winnr].signcolumn = "no"

  render()
end

function M.close()
  if is_open() then
    vim.api.nvim_win_close(winnr, true)
  end
  winnr = nil
end

function M.toggle()
  if is_open() then
    M.close()
  else
    M.open()
  end
end

function M.refresh()
  if is_open() then
    render()
  end
end

return M
