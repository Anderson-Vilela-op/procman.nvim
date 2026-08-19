local config = require("procman.config")

describe("config.project_for_root", function()
  before_each(function()
    config.setup({
      projects = {
        ["~/Workspace/rca"] = { services = { web = { cmd = "npm run dev" } } },
      },
    })
  end)

  it("matches the path after expanding ~ and normalizing the trailing slash", function()
    local home = vim.fn.expand("~")
    local found = config.project_for_root(home .. "/Workspace/rca/")
    assert.is_not_nil(found)
    assert.same({ cmd = "npm run dev" }, found.services.web)
  end)

  it("returns nil when no project matches", function()
    assert.is_nil(config.project_for_root("/tmp/some-other-project"))
  end)
end)
