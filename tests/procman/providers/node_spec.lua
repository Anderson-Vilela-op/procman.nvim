local helpers = require("tests.helpers")
local node = require("procman.providers.node")

local function scan(dir)
  local entries = {}
  for name, kind_ in vim.fs.dir(dir) do
    table.insert(entries, { name = name, type = kind_ })
  end
  return entries
end

describe("providers.node", function()
  local dir

  after_each(function()
    if dir then
      helpers.rmdir(dir)
      dir = nil
    end
  end)

  it("uses 'npm run dev' when the dev script exists, and exposes the other scripts with a suffix", function()
    dir = helpers.tmpdir()
    helpers.write(dir .. "/package.json", '{"scripts":{"dev":"vite","build":"vite build","lint":"eslint ."}}')

    local entries = scan(dir)
    assert.is_true(node.detect(dir, entries))

    local found = node.discover(dir, entries, dir)
    local name = vim.fs.basename(dir)
    assert.same({ "npm", "run", "dev" }, found[name].cmd)
    assert.same({ "npm", "run", "build" }, found[name .. ":build"].cmd)
    assert.same({ "npm", "run", "lint" }, found[name .. ":lint"].cmd)
    assert.is_nil(found[name .. ":dev"])
  end)

  it("uses 'npm start' when the start script exists but not dev", function()
    dir = helpers.tmpdir()
    helpers.write(dir .. "/package.json", '{"scripts":{"start":"node server.js","build":"tsc"}}')

    local entries = scan(dir)
    local found = node.discover(dir, entries, dir)
    local name = vim.fs.basename(dir)
    assert.same({ "npm", "start" }, found[name].cmd)
    assert.same({ "npm", "run", "build" }, found[name .. ":build"].cmd)
  end)

  it("without dev or start: each script becomes only a suffixed entry, with no default service", function()
    dir = helpers.tmpdir()
    helpers.write(dir .. "/package.json", '{"scripts":{"build":"tsc","test":"jest"}}')

    local entries = scan(dir)
    local found = node.discover(dir, entries, dir)
    local name = vim.fs.basename(dir)
    assert.is_nil(found[name])
    assert.same({ "npm", "run", "build" }, found[name .. ":build"].cmd)
    assert.same({ "npm", "run", "test" }, found[name .. ":test"].cmd)
  end)

  it("does not detect a package.json with no scripts (avoids a service that always fails)", function()
    dir = helpers.tmpdir()
    helpers.write(dir .. "/package.json", '{"name":"workspace-root"}')

    local entries = scan(dir)
    assert.is_false(node.detect(dir, entries))
  end)
end)
