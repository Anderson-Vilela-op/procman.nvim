local M = {}

M.filename = ".procman.lua"

function M.path(root)
  return root .. "/" .. M.filename
end

function M.load(root)
  local path = M.path(root)
  if vim.fn.filereadable(path) == 0 then
    return {}
  end

  local chunk, load_err = loadfile(path)
  if not chunk then
    vim.notify("[procman] failed to load " .. path .. ": " .. load_err, vim.log.levels.ERROR)
    return {}
  end

  local ok, result = pcall(chunk)
  if not ok then
    vim.notify("[procman] failed to run " .. path .. ": " .. result, vim.log.levels.ERROR)
    return {}
  end

  if type(result) ~= "table" then
    vim.notify("[procman] " .. path .. " must return a table (e.g. `return { services = {...} } `)", vim.log.levels.ERROR)
    return {}
  end

  return result.services or {}
end

local function fmt_cmd(cmd)
  if type(cmd) == "string" then
    return string.format("%q", cmd)
  end
  local parts = {}
  for _, arg in ipairs(cmd) do
    table.insert(parts, string.format("%q", arg))
  end
  return "{ " .. table.concat(parts, ", ") .. " }"
end
M.fmt_cmd = fmt_cmd

function M.add_service(root, name, cfg, discovered)
  local path = M.path(root)

  if vim.fn.filereadable(path) == 0 then
    vim.fn.writefile(vim.split(M.template(root, discovered or {}), "\n"), path)
  end

  local lines = vim.fn.readfile(path)
  local insert_at = nil
  for i, line in ipairs(lines) do
    if line:match("^%s*services%s*=%s*{%s*$") then
      insert_at = i
      break
    end
  end

  if not insert_at then
    return false, "could not find the 'services = {' line in " .. path .. " -- add it manually"
  end

  local entry = string.format(
    "    [%q] = { cmd = %s, cwd = %q, kind = %q },",
    name, fmt_cmd(cfg.cmd), cfg.cwd or "", cfg.kind or "custom"
  )
  table.insert(lines, insert_at + 1, entry)
  vim.fn.writefile(lines, path)
  return true
end

function M.template(root, discovered)
  local lines = {
    "-- procman.nvim service config for this project.",
    "-- Loaded automatically (setup_services) and merged with what was",
    "-- auto-discovered and with the `services` passed to setup() in your",
    "-- init.lua (which takes priority over this file on conflict).",
    "return {",
    "  services = {",
  }

  local names = vim.tbl_keys(discovered)
  table.sort(names)
  if #names > 0 then
    table.insert(lines, "    -- auto-discovered (uncomment/adjust to override):")
    for _, name in ipairs(names) do
      local cfg = discovered[name]
      local rel_cwd = cfg.cwd
      if rel_cwd and rel_cwd:sub(1, #root) == root then
        rel_cwd = rel_cwd:sub(#root + 2)
      end
      table.insert(lines, string.format(
        "    -- %s = { cmd = %s, cwd = %q, kind = %q },",
        name, fmt_cmd(cfg.cmd), rel_cwd or "", cfg.kind or ""
      ))
    end
    table.insert(lines, "")
  end

  table.insert(lines, "    -- example:")
  table.insert(lines, "    -- api = { cmd = \"dotnet run --project src/Api/Api.csproj\", cwd = \"backend\" },")
  table.insert(lines, "    -- web = { cmd = { \"npm\", \"run\", \"dev\" }, cwd = \"frontend\", env = { NODE_ENV = \"development\" } },")
  table.insert(lines, "  },")
  table.insert(lines, "}")

  return table.concat(lines, "\n") .. "\n"
end

return M
