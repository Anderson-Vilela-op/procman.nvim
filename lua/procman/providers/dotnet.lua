local M = {}
M.name = "dotnet"

local function read_file(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local content = f:read("*a")
  f:close()
  return content
end

local function find_entry(entries, pattern)
  for _, e in ipairs(entries) do
    if e.type == "file" and e.name:match(pattern) then
      return e.name
    end
  end
  return nil
end

local function parse_sln(path)
  local content = read_file(path)
  if not content then
    return {}
  end
  local projects = {}
  for name, relpath in content:gmatch('Project%("{[^}]+}"%)%s*=%s*"([^"]+)",%s*"([^"]+)"') do
    if relpath:match("%.csproj$") then
      table.insert(projects, { name = name, path = (relpath:gsub("\\", "/")) })
    end
  end
  return projects
end

local function parse_slnx(path)
  local content = read_file(path)
  if not content then
    return {}
  end
  local projects = {}
  for relpath in content:gmatch('<Project%s+[^>]-Path="([^"]+)"') do
    if relpath:match("%.csproj$") then
      local norm = (relpath:gsub("\\", "/"))
      local name = norm:match("([^/]+)%.csproj$")
      table.insert(projects, { name = name, path = norm })
    end
  end
  return projects
end

local function is_test_project(csproj_path)
  local content = read_file(csproj_path) or ""
  if content:match("Microsoft%.NET%.Test%.Sdk") then
    return true
  end
  if content:match("<IsTestProject>%s*[Tt]rue%s*</IsTestProject>") then
    return true
  end
  local base = csproj_path:match("([^/]+)$") or csproj_path
  return base:match("[Tt]ests?%.csproj$") ~= nil
end

function M.detect(dir, entries)
  for _, e in ipairs(entries) do
    if e.type == "file" and (e.name:match("%.slnx?$") or e.name:match("%.csproj$")) then
      return true
    end
  end
  return false
end

local function add_project_tasks(found, dir, name, relpath)
  local csproj_path = dir .. "/" .. relpath
  if is_test_project(csproj_path) then
    found[name .. ":test"] = {
      cmd = { "dotnet", "test", relpath },
      cwd = dir,
      kind = "dotnet",
      autostart = false,
    }
  else
    found[name] = {
      cmd = { "dotnet", "run", "--project", relpath },
      cwd = dir,
      kind = "dotnet",
      autostart = false,
    }
  end
  found[name .. ":build"] = {
    cmd = { "dotnet", "build", relpath },
    cwd = dir,
    kind = "dotnet",
    autostart = false,
  }
end

function M.discover(dir, entries, _root)
  local found = {}

  local sln = find_entry(entries, "%.slnx$") or find_entry(entries, "%.sln$")
  if sln then
    local sln_path = dir .. "/" .. sln
    local sln_name = sln:gsub("%.slnx?$", "")
    local projects = sln:match("%.slnx$") and parse_slnx(sln_path) or parse_sln(sln_path)

    for _, proj in ipairs(projects) do
      add_project_tasks(found, dir, proj.name, proj.path)
    end

    found[sln_name .. ":build"] = { cmd = { "dotnet", "build", sln }, cwd = dir, kind = "dotnet", autostart = false }
    found[sln_name .. ":test"] = { cmd = { "dotnet", "test", sln }, cwd = dir, kind = "dotnet", autostart = false }
    found[sln_name .. ":restore"] = { cmd = { "dotnet", "restore", sln }, cwd = dir, kind = "dotnet", autostart = false }

    return found
  end

  for _, e in ipairs(entries) do
    if e.type == "file" and e.name:match("%.csproj$") then
      local name = e.name:gsub("%.csproj$", "")
      add_project_tasks(found, dir, name, e.name)
    end
  end

  return found
end

return M
