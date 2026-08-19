local helpers = require("tests.helpers")
local discover = require("procman.discover")

describe("discover", function()
  local dir

  after_each(function()
    if dir then
      helpers.rmdir(dir)
      dir = nil
    end
  end)

  it("does not descend into directories listed in discover_ignore", function()
    dir = helpers.tmpdir()
    helpers.write(dir .. "/node_modules/pkg/package.json", '{"scripts":{"dev":"x"}}')

    local found = discover.discover(dir, 5, { "node_modules" })
    assert.same({}, found)
  end)

  it("respects discover_depth", function()
    dir = helpers.tmpdir()
    helpers.write(dir .. "/a/b/package.json", '{"scripts":{"dev":"x"}}')

    assert.same({}, discover.discover(dir, 1, {}))

    local found = discover.discover(dir, 3, {})
    assert.same({ "npm", "run", "dev" }, found["b"].cmd)
  end)

  it("keeps descending into subfolders even when the root already has a recognized marker", function()
    dir = helpers.tmpdir()
    helpers.write(dir .. "/MySolution.sln", {
      'Project("{X}") = "Api", "src/Api/Api.csproj", "{111}"',
      "EndProject",
    })
    helpers.write(dir .. "/src/Api/Api.csproj", '<Project Sdk="Microsoft.NET.Sdk.Web"></Project>')
    helpers.write(dir .. "/frontend/package.json", '{"scripts":{"dev":"vite"}}')
    helpers.write(dir .. "/worker/Cargo.toml", '[package]\nname = "worker"')

    local found = discover.discover(dir, 3, { "node_modules", ".git" })

    assert.same({ "dotnet", "run", "--project", "src/Api/Api.csproj" }, found["Api"].cmd)
    assert.same({ "dotnet", "build", "MySolution.sln" }, found["MySolution:build"].cmd)
    assert.same({ "npm", "run", "dev" }, found["frontend"].cmd)
    assert.same({ "cargo", "run" }, found["worker"].cmd)
  end)

  it("monorepo: recognizes .NET, Node and Rust in sibling subfolders, each with its own provider", function()
    dir = helpers.tmpdir()
    helpers.write(dir .. "/backend/Backend.sln", {
      'Project("{X}") = "Api", "Api.csproj", "{111}"',
      "EndProject",
    })
    helpers.write(dir .. "/backend/Api.csproj", '<Project Sdk="Microsoft.NET.Sdk.Web"></Project>')
    helpers.write(dir .. "/frontend/package.json", '{"scripts":{"dev":"vite"}}')
    helpers.write(dir .. "/worker/Cargo.toml", '[package]\nname = "worker"')

    local found = discover.discover(dir, 3, { "node_modules", ".git" })

    assert.same({ "dotnet", "run", "--project", "Api.csproj" }, found["Api"].cmd)
    assert.same({ "dotnet", "build", "Backend.sln" }, found["Backend:build"].cmd)
    assert.same({ "npm", "run", "dev" }, found["frontend"].cmd)
    assert.same({ "cargo", "run" }, found["worker"].cmd)
  end)
end)
