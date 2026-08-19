local M = {}

local uv = vim.loop
local providers = require("procman.providers")

local function scandir(dir)
  local entries = {}
  local fd = uv.fs_scandir(dir)
  if not fd then
    return entries
  end
  while true do
    local name, kind_ = uv.fs_scandir_next(fd)
    if not name then
      break
    end
    table.insert(entries, { name = name, type = kind_ })
  end
  return entries
end

function M.discover(root, max_depth, ignore)
  local ignore_set = {}
  for _, name in ipairs(ignore or {}) do
    ignore_set[name] = true
  end

  local found = {}

  local function walk(dir, depth, suppressed)
    if depth > max_depth then
      return
    end
    local entries = scandir(dir)
    local child_suppressed = suppressed

    for _, provider in ipairs(providers.all) do
      if not suppressed[provider.name] and provider.detect(dir, entries) then
        local svcs = provider.discover(dir, entries, root)
        for name, cfg in pairs(svcs) do
          found[name] = cfg
        end
        if child_suppressed == suppressed then
          child_suppressed = vim.tbl_extend("force", {}, suppressed)
        end
        child_suppressed[provider.name] = true
      end
    end

    for _, entry in ipairs(entries) do
      if entry.type == "directory" and not ignore_set[entry.name] and not entry.name:match("^%.") then
        walk(dir .. "/" .. entry.name, depth + 1, child_suppressed)
      end
    end
  end

  walk(root, 0, {})
  return found
end

return M
