local helpers = require("tests.helpers")
local dotnet = require("procman.providers.dotnet")

local function scan(dir)
  local entries = {}
  for name, kind_ in vim.fs.dir(dir) do
    table.insert(entries, { name = name, type = kind_ })
  end
  return entries
end

describe("providers.dotnet", function()
  local dir

  after_each(function()
    if dir then
      helpers.rmdir(dir)
      dir = nil
    end
  end)

  it("parses .sln: run+build per project, and build/test/restore for the solution", function()
    dir = helpers.tmpdir()
    helpers.write(dir .. "/MySolution.sln", {
      'Microsoft Visual Studio Solution File, Format Version 12.00',
      'Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "Api", "src\\Api\\Api.csproj", "{111}"',
      "EndProject",
    })
    helpers.write(dir .. "/src/Api/Api.csproj", {
      '<Project Sdk="Microsoft.NET.Sdk.Web">',
      "  <PropertyGroup><OutputType>Exe</OutputType></PropertyGroup>",
      "</Project>",
    })

    local entries = scan(dir)
    assert.is_true(dotnet.detect(dir, entries))

    local found = dotnet.discover(dir, entries, dir)

    assert.same({ "dotnet", "run", "--project", "src/Api/Api.csproj" }, found["Api"].cmd)
    assert.same({ "dotnet", "build", "src/Api/Api.csproj" }, found["Api:build"].cmd)
    assert.same({ "dotnet", "build", "MySolution.sln" }, found["MySolution:build"].cmd)
    assert.same({ "dotnet", "test", "MySolution.sln" }, found["MySolution:test"].cmd)
    assert.same({ "dotnet", "restore", "MySolution.sln" }, found["MySolution:restore"].cmd)
    assert.is_nil(found["Api:test"])
  end)

  it("detects a test project via a reference to Microsoft.NET.Test.Sdk", function()
    dir = helpers.tmpdir()
    helpers.write(dir .. "/S.sln", {
      'Project("{X}") = "Checks", "Checks.csproj", "{111}"',
      "EndProject",
    })
    helpers.write(dir .. "/Checks.csproj", {
      '<Project Sdk="Microsoft.NET.Sdk">',
      "  <ItemGroup>",
      '    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.8.0" />',
      "  </ItemGroup>",
      "</Project>",
    })

    local entries = scan(dir)
    local found = dotnet.discover(dir, entries, dir)

    assert.same({ "dotnet", "test", "Checks.csproj" }, found["Checks:test"].cmd)
    assert.is_nil(found["Checks"])
  end)

  it("detects a test project by naming convention, even without Test.Sdk", function()
    dir = helpers.tmpdir()
    helpers.write(dir .. "/S.sln", {
      'Project("{X}") = "Api.Tests", "Api.Tests.csproj", "{111}"',
      "EndProject",
    })
    helpers.write(dir .. "/Api.Tests.csproj", { '<Project Sdk="Microsoft.NET.Sdk"></Project>' })

    local entries = scan(dir)
    local found = dotnet.discover(dir, entries, dir)

    assert.same({ "dotnet", "test", "Api.Tests.csproj" }, found["Api.Tests:test"].cmd)
    assert.is_nil(found["Api.Tests"])
  end)

  it("parses .slnx (XML) the same way as .sln", function()
    dir = helpers.tmpdir()
    helpers.write(dir .. "/MySolution.slnx", {
      "<Solution>",
      '  <Project Path="src/Api/Api.csproj" />',
      "</Solution>",
    })
    helpers.write(dir .. "/src/Api/Api.csproj", { '<Project Sdk="Microsoft.NET.Sdk.Web"></Project>' })

    local entries = scan(dir)
    local found = dotnet.discover(dir, entries, dir)

    assert.same({ "dotnet", "run", "--project", "src/Api/Api.csproj" }, found["Api"].cmd)
    assert.same({ "dotnet", "build", "MySolution.slnx" }, found["MySolution:build"].cmd)
  end)

  it("without .sln/.slnx, falls back to a standalone csproj (run+build per file)", function()
    dir = helpers.tmpdir()
    helpers.write(dir .. "/Standalone.csproj", {
      '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType></PropertyGroup></Project>',
    })

    local entries = scan(dir)
    assert.is_true(dotnet.detect(dir, entries))

    local found = dotnet.discover(dir, entries, dir)
    assert.same({ "dotnet", "run", "--project", "Standalone.csproj" }, found["Standalone"].cmd)
    assert.same({ "dotnet", "build", "Standalone.csproj" }, found["Standalone:build"].cmd)
    assert.is_nil(found["MySolution:build"])
  end)
end)
