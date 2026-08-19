local M = {}

local defaults = {
  root = nil,

  auto_discover = true,

  discover_depth = 3,

  discover_ignore = {
    "node_modules", ".git", "bin", "obj", "target", "dist", "build", ".venv",
  },

  services = {},

  projects = {},

  poll_interval = 2000,

  log_max_lines = 5000,

  panel = {
    position = "right",
    width = 42,
    height = 12,
    icons = {
      running = "●",
      stopped = "○",
      failed = "✗",
      starting = "◐",
    },
  },

  log_window = {
    relative = "editor",
    width = 0.8,
    height = 0.7,
    border = "rounded",
  },

  panel_keymaps = {
    start = "s",
    stop = "x",
    restart = "r",
    start_all = "S",
    stop_all = "X",
    logs = "<CR>",
    close = "q",
    refresh = "R",
    toggle_group = "za",
    add = "a",
    hide = "H",
    show_hidden = "E",
  },

  log_keymaps = {
    close = "q",
    stop = "x",
    restart = "r",
    scroll_end = "G",
  },
}

M.options = vim.deepcopy(defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  if not M.options.root then
    M.options.root = vim.loop.cwd()
  end
  return M.options
end

local function normalize_path(path)
  if not path or path == "" then
    return nil
  end
  local expanded = vim.fn.fnamemodify(vim.fn.expand(path), ":p")
  return (expanded:gsub("/+$", ""))
end

function M.project_for_root(root)
  local target = normalize_path(root)
  if not target then
    return nil
  end
  for path, project_opts in pairs(M.options.projects or {}) do
    if normalize_path(path) == target then
      return project_opts
    end
  end
  return nil
end

return M
