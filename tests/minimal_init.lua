local root = vim.fn.fnamemodify(vim.fn.resolve(debug.getinfo(1, 'S').source:sub(2)), ':p:h:h')

vim.opt.runtimepath:prepend(root)
vim.opt.runtimepath:prepend(root .. '/.tests/plenary.nvim')
vim.opt.runtimepath:prepend(root .. '/.tests')

vim.opt.swapfile = false
