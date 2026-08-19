local M = {}

function M.tmpdir()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  return dir
end

function M.write(path, content)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  local lines = type(content) == "table" and content or vim.split(content, "\n")
  vim.fn.writefile(lines, path)
end

function M.rmdir(dir)
  vim.fn.delete(dir, "rf")
end

return M
