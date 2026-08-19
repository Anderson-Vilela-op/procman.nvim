local M = {}

M.all = {
  require("procman.providers.dotnet"),
  require("procman.providers.node"),
  require("procman.providers.rust"),
  require("procman.providers.go"),
}

return M
