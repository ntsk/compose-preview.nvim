local M = {}

function M.default_path()
  return vim.fs.joinpath(vim.fn.stdpath('log'), 'compose-preview.log')
end

function M.format(level, message, timestamp)
  local text = tostring(message):gsub('\n', '\n    ')
  return ('[%s] %s %s'):format(timestamp, level, text)
end

function M.write(level, message, opts)
  opts = opts or {}
  local path = opts.path or M.default_path()

  vim.fn.mkdir(vim.fs.dirname(path), 'p')

  local line = M.format(level, message, os.date('%Y-%m-%d %H:%M:%S'))
  local ok = pcall(function()
    local handle = assert(io.open(path, 'a'))
    handle:write(line .. '\n')
    handle:close()
  end)

  return ok
end

function M.info(message)
  M.write('INFO', message)
end

function M.error(message)
  M.write('ERROR', message)
end

return M
