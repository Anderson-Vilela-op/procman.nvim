local M = {}
M.name = "node"

local function read_package_json(dir)
  local ok, decoded = pcall(function()
    local f = io.open(dir .. "/package.json", "r")
    if not f then
      return nil
    end
    local content = f:read("*a")
    f:close()
    return vim.json.decode(content)
  end)
  return ok and decoded or nil
end

local function has_scripts(dir)
  local decoded = read_package_json(dir)
  return decoded ~= nil and type(decoded.scripts) == "table" and next(decoded.scripts) ~= nil
end

function M.detect(dir, entries)
  for _, e in ipairs(entries) do
    if e.type == "file" and e.name == "package.json" then
      return has_scripts(dir)
    end
  end
  return false
end

function M.discover(dir, _entries, root)
  local decoded = read_package_json(dir)
  local scripts = (decoded and type(decoded.scripts) == "table") and decoded.scripts or {}
  local name = vim.fs.basename(dir)
  if name == "" or name == "." then
    name = vim.fs.basename(root)
  end

  local primary_script = scripts.dev and "dev" or (scripts.start and "start" or nil)

  local found = {}
  if primary_script then
    local cmd = primary_script == "start" and { "npm", "start" } or { "npm", "run", primary_script }
    found[name] = { cmd = cmd, cwd = dir, kind = "node", autostart = false }
  end

  for script_name in pairs(scripts) do
    if script_name ~= primary_script then
      found[name .. ":" .. script_name] = {
        cmd = { "npm", "run", script_name },
        cwd = dir,
        kind = "node",
        autostart = false,
      }
    end
  end

  return found
end

return M
