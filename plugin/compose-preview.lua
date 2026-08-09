if vim.g.loaded_compose_preview then
  return
end
vim.g.loaded_compose_preview = true

vim.api.nvim_create_user_command('ComposePreview', function()
  require('compose-preview').open()
end, { desc = 'Render @Preview in this file and open it in a browser' })

vim.api.nvim_create_user_command('ComposePreviewLog', function()
  vim.cmd.tabedit(vim.fn.fnameescape(require('compose-preview').log_path()))
  vim.cmd.normal({ args = { 'G' }, bang = true })
end, { desc = 'Open the compose-preview log' })
