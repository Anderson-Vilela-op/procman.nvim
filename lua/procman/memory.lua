local M = {}

function M.snapshot(callback)
  if not vim.system then
    callback(nil, "requires Neovim >= 0.10 (vim.system)")
    return
  end

  vim.system({ "ps", "-eo", "pid,ppid,rss" }, { text = true }, function(res)
    if res.code ~= 0 or not res.stdout then
      vim.schedule(function()
        callback(nil, res.stderr or "failed to run ps")
      end)
      return
    end

    local tree = {}
    for line in res.stdout:gmatch("[^\r\n]+") do
      local pid, ppid, rss = line:match("^%s*(%d+)%s+(%d+)%s+(%d+)")
      if pid then
        tree[tonumber(pid)] = { ppid = tonumber(ppid), rss = tonumber(rss) }
      end
    end

    vim.schedule(function()
      callback(tree, nil)
    end)
  end)
end

function M.children_by_ppid(tree)
  local children = {}
  for pid, info in pairs(tree) do
    children[info.ppid] = children[info.ppid] or {}
    table.insert(children[info.ppid], pid)
  end
  return children
end

function M.total_rss_kb(tree, root_pid, children)
  if not tree[root_pid] then
    return 0
  end

  local total = 0
  local stack = { root_pid }
  local visited = {}
  while #stack > 0 do
    local pid = table.remove(stack)
    if not visited[pid] then
      visited[pid] = true
      local info = tree[pid]
      if info then
        total = total + info.rss
      end
      for _, child in ipairs(children[pid] or {}) do
        table.insert(stack, child)
      end
    end
  end
  return total
end

function M.format_kb(kb)
  if not kb or kb <= 0 then
    return "-"
  end
  if kb < 1024 then
    return string.format("%dKB", kb)
  end
  local mb = kb / 1024
  if mb < 1024 then
    return string.format("%.1fMB", mb)
  end
  return string.format("%.2fGB", mb / 1024)
end

return M
