local M = {}
M.name = "go"

function M.detect(dir, entries)
  for _, e in ipairs(entries) do
    if e.type == "file" and e.name == "go.mod" then
      return true
    end
  end
  return false
end

function M.discover(dir, _entries, root)
  local name = vim.fs.basename(dir)
  if name == "" or name == "." then
    name = vim.fs.basename(root)
  end
  return {
    [name] = { cmd = { "go", "run", "." }, cwd = dir, kind = "go", autostart = false },
  }
end

return M
