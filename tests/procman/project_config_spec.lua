local helpers = require("tests.helpers")
local project_config = require("procman.project_config")

describe("project_config.load", function()
  local dir

  after_each(function()
    if dir then
      helpers.rmdir(dir)
      dir = nil
    end
  end)

  it("returns an empty table when .procman.lua does not exist", function()
    dir = helpers.tmpdir()
    assert.same({}, project_config.load(dir))
  end)

  it("returns the services from a valid .procman.lua", function()
    dir = helpers.tmpdir()
    helpers.write(dir .. "/.procman.lua", {
      "return {",
      "  services = {",
      '    api = { cmd = "dotnet run", cwd = "src" },',
      "  },",
      "}",
    })

    local services = project_config.load(dir)
    assert.same({ cmd = "dotnet run", cwd = "src" }, services.api)
  end)

  it("returns an empty table (without erroring) when the file does not return a table", function()
    dir = helpers.tmpdir()
    helpers.write(dir .. "/.procman.lua", { "return 42" })

    local notified = false
    local original_notify = vim.notify
    vim.notify = function(_, level)
      notified = level == vim.log.levels.ERROR
    end

    local ok, result = pcall(project_config.load, dir)
    vim.notify = original_notify

    assert.is_true(ok)
    assert.same({}, result)
    assert.is_true(notified)
  end)
end)

describe("project_config.add_service", function()
  local dir

  after_each(function()
    if dir then
      helpers.rmdir(dir)
      dir = nil
    end
  end)

  it("creates .procman.lua (from the template) when it does not exist yet", function()
    dir = helpers.tmpdir()
    assert.equals(0, vim.fn.filereadable(project_config.path(dir)))

    local ok = project_config.add_service(dir, "api", { cmd = "dotnet run", cwd = "backend", kind = "dotnet" })
    assert.is_true(ok)

    local services = project_config.load(dir)
    assert.same({ cmd = "dotnet run", cwd = "backend", kind = "dotnet" }, services.api)
  end)

  it("inserts into an existing file without erasing already-declared services", function()
    dir = helpers.tmpdir()
    helpers.write(dir .. "/.procman.lua", {
      "return {",
      "  services = {",
      '    api = { cmd = "dotnet run", cwd = "src" },',
      "  },",
      "}",
    })

    local ok = project_config.add_service(dir, "web", { cmd = { "npm", "run", "dev" }, cwd = "frontend", kind = "node" })
    assert.is_true(ok)

    local services = project_config.load(dir)
    assert.same({ cmd = "dotnet run", cwd = "src" }, services.api)
    assert.same({ cmd = { "npm", "run", "dev" }, cwd = "frontend", kind = "node" }, services.web)
  end)

  it("names with ':' or '-' (e.g. a sub-command script) do not break the generated Lua", function()
    dir = helpers.tmpdir()

    local ok = project_config.add_service(dir, "rcafarma-client:build", { cmd = "npm run build", cwd = "", kind = "node" })
    assert.is_true(ok)

    local services = project_config.load(dir)
    assert.same({ cmd = "npm run build", cwd = "", kind = "node" }, services["rcafarma-client:build"])
  end)
end)
