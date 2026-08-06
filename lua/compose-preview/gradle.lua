local log = require('compose-preview.log')

local M = {}

local BEGIN_MARKER = 'COMPOSE_PREVIEW_INFO_BEGIN'
local END_MARKER = 'COMPOSE_PREVIEW_INFO_END'

local function denil(value)
  if value == vim.NIL then
    return nil
  end
  if type(value) ~= 'table' then
    return value
  end

  local result = {}
  for key, item in pairs(value) do
    result[key] = denil(item)
  end
  return result
end

function M.parse_info(stdout)
  local infos = {}
  local block, inside = nil, false

  for line in (stdout .. '\n'):gmatch('([^\n]*)\n') do
    local trimmed = vim.trim(line)
    if trimmed == BEGIN_MARKER then
      inside, block = true, {}
    elseif trimmed == END_MARKER and inside then
      local ok, decoded = pcall(vim.json.decode, table.concat(block, '\n'))
      if not ok then
        return nil, ('failed to parse JSON emitted by Gradle: %s'):format(tostring(decoded))
      end
      table.insert(infos, denil(decoded))
      inside = false
    elseif inside then
      table.insert(block, line)
    end
  end

  if #infos == 0 then
    return nil, 'Gradle output contains no preview info'
  end

  return infos
end

function M.find_project_root(path)
  local found = vim.fs.find('gradlew', {
    path = vim.fs.dirname(path),
    upward = true,
    type = 'file',
  })[1]

  return found and vim.fs.dirname(found) or nil
end

function M.find_module(root, path)
  local found = vim.fs.find({ 'build.gradle.kts', 'build.gradle' }, {
    path = vim.fs.dirname(path),
    upward = true,
    type = 'file',
    stop = vim.fs.dirname(root),
  })[1]

  if not found then
    return nil
  end

  local dir = vim.fs.dirname(found)
  if dir == root then
    return ''
  end

  return ':' .. dir:sub(#root + 2):gsub('/', ':')
end

function M.init_script()
  return vim.api.nvim_get_runtime_file('gradle/compose-preview.init.gradle', false)[1]
end

function M.command(opts)
  local cmd = {
    vim.fs.joinpath(opts.root, 'gradlew'),
    '--console=plain',
    '-q',
    (opts.module or '') .. ':composePreviewInfo',
    '--init-script',
    opts.init_script,
  }

  if opts.variant then
    table.insert(cmd, '-PcomposePreviewVariant=' .. opts.variant)
  end

  return cmd
end

function M.first_error_line(result)
  local combined = (result.stderr or '') .. '\n' .. (result.stdout or '')

  for line in combined:gmatch('[^\n]+') do
    local trimmed = vim.trim(line)
    if trimmed:match('^%*?%s*What went wrong') or trimmed:match('^FAILURE:') or trimmed:match('^error:') then
      return trimmed
    end
  end

  for line in combined:gmatch('[^\n]+') do
    local trimmed = vim.trim(line)
    if trimmed ~= '' then
      return trimmed
    end
  end

  return 'see :ComposePreviewLog for details'
end

function M.describe_variant_error(variant, available)
  return ('variant %s not found. available variants: %s'):format(
    tostring(variant),
    table.concat(available or {}, ', ')
  )
end

function M.build_and_inspect(opts, on_done)
  local init_script = opts.init_script or M.init_script()
  if not init_script then
    return on_done('Gradle init script not found')
  end

  local cmd = M.command({
    root = opts.root,
    module = opts.module,
    variant = opts.variant,
    init_script = init_script,
  })

  log.info('running: ' .. table.concat(cmd, ' '))

  vim.system(cmd, { cwd = opts.root, text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        log.error(('Gradle exited %d\n--- stderr ---\n%s\n--- stdout ---\n%s'):format(
          result.code,
          result.stderr or '',
          result.stdout or ''
        ))
        return on_done(('Gradle failed (exit %d): %s'):format(result.code, M.first_error_line(result)))
      end

      local infos, err = M.parse_info(result.stdout or '')
      if not infos then
        log.error(('could not parse Gradle output\n--- stdout ---\n%s'):format(result.stdout or ''))
        return on_done(err)
      end

      local info = infos[1]
      if info.error then
        return on_done(M.describe_variant_error(info.variant, info.availableVariants))
      end

      on_done(nil, info, infos)
    end)
  end)
end

return M
