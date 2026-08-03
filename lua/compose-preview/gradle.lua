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
        return nil, ('Gradle が出力した JSON を解析できません: %s'):format(tostring(decoded))
      end
      table.insert(infos, denil(decoded))
      inside = false
    elseif inside then
      table.insert(block, line)
    end
  end

  if #infos == 0 then
    return nil, 'Gradle の出力にプレビュー情報が含まれていません'
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

local function capitalize(word)
  return word:sub(1, 1):upper() .. word:sub(2)
end

function M.tasks(module, variant)
  local prefix = module or ''
  local suffix = capitalize(variant)

  return {
    prefix .. ':process' .. suffix .. 'Resources',
    prefix .. ':compile' .. suffix .. 'Kotlin',
    prefix .. ':composePreviewInfo',
  }
end

function M.build_and_inspect(opts, on_done)
  local init_script = opts.init_script or M.init_script()
  if not init_script then
    return on_done('Gradle init script が見つかりません')
  end

  local variant = opts.variant or 'debug'
  local cmd = { vim.fs.joinpath(opts.root, 'gradlew'), '--console=plain', '-q' }
  vim.list_extend(cmd, M.tasks(opts.module, variant))
  vim.list_extend(cmd, { '--init-script', init_script, '-PcomposePreviewVariant=' .. variant })

  vim.system(cmd, { cwd = opts.root, text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        return on_done(('Gradle の実行に失敗しました (exit %d):\n%s'):format(result.code, result.stderr or ''))
      end

      local infos, err = M.parse_info(result.stdout or '')
      if not infos then
        return on_done(err)
      end

      on_done(nil, infos[1], infos)
    end)
  end)
end

return M
