local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
local plenary_dir = root .. "/.tests/site/pack/deps/start/plenary.nvim"

vim.opt.rtp:prepend(root)
vim.opt.rtp:append(plenary_dir)

vim.cmd("runtime! plugin/plenary.vim")
