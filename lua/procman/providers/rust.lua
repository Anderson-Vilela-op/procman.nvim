local M = {}
M.name = "rust"

function M.detect(dir, entries)
  for _, e in ipairs(entries) do
    if e.type == "file" and e.name == "Cargo.toml" then
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
    [name] = { cmd = { "cargo", "run" }, cwd = dir, kind = "rust", autostart = false },
  }
end

return M
