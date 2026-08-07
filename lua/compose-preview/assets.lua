local M = {}

local cache = {}

local function read(name)
  if cache[name] then
    return cache[name]
  end

  local path = vim.api.nvim_get_runtime_file('assets/' .. name, false)[1]
  local contents = path and table.concat(vim.fn.readfile(path), '\n') or ''
  cache[name] = contents

  return contents
end

function M.style()
  return read('preview.css')
end

function M.script()
  return read('preview.js')
end

return M
