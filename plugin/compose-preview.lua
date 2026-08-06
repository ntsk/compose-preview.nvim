if vim.g.loaded_compose_preview then
  return
end
vim.g.loaded_compose_preview = true

vim.api.nvim_create_user_command('ComposePreview', function()
  require('compose-preview').open()
end, { desc = 'Render @Preview in this file and open it in a browser' })
