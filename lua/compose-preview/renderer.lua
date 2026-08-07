local results = require('compose-preview.results')

local M = {}

M.MINIMUM_JAVA_VERSION = 21
M.MAIN_CLASS = 'com.android.tools.render.common.MainKt'
M.DEFAULT_TIMEOUT_MS = 180000

function M.parse_java_version(output)
  local version = output:match('version%s+"([%d._]+)"')
  if not version then
    return nil
  end

  local first, second = version:match('^(%d+)%.(%d+)')
  if first == '1' then
    return tonumber(second)
  end

  return tonumber(version:match('^(%d+)'))
end

local function java_version_of(path)
  local result = vim.system({ path, '-version' }, { text = true }):wait()
  if result.code ~= 0 then
    return nil
  end
  return M.parse_java_version((result.stderr or '') .. (result.stdout or ''))
end

function M.find_java()
  local candidates = {}

  if vim.env.JAVA_HOME and vim.env.JAVA_HOME ~= '' then
    table.insert(candidates, vim.fs.joinpath(vim.env.JAVA_HOME, 'bin', 'java'))
  end

  if vim.fn.executable('/usr/libexec/java_home') == 1 then
    local home = vim
      .system({ '/usr/libexec/java_home', '-v', tostring(M.MINIMUM_JAVA_VERSION) }, { text = true })
      :wait()
    if home.code == 0 then
      table.insert(candidates, vim.fs.joinpath(vim.trim(home.stdout), 'bin', 'java'))
    end
  end

  table.insert(candidates, 'java')

  for _, candidate in ipairs(candidates) do
    if candidate == 'java' or vim.fn.executable(candidate) == 1 then
      local version = java_version_of(candidate)
      if version and version >= M.MINIMUM_JAVA_VERSION then
        return candidate
      end
    end
  end

  return nil, ('Java %d or newer not found. set opts.java to an absolute path to java'):format(M.MINIMUM_JAVA_VERSION)
end

function M.java_home(java_path)
  if not java_path then
    return nil
  end

  local home = java_path:match('^(.*)/bin/java$')
  return home
end

function M.command(opts)
  return { opts.java, '-cp', opts.classpath, M.MAIN_CLASS, opts.settings_path }
end

function M.render(opts, on_done)
  local java = opts.java
  if not java then
    local found, err = M.find_java()
    if not found then
      return vim.schedule(function()
        on_done(err)
      end)
    end
    java = found
  end

  local cmd = M.command({
    java = java,
    classpath = opts.classpath,
    settings_path = opts.settings_path,
  })

  local spawned, spawn_err = pcall(vim.system, cmd, {
    text = true,
    timeout = opts.timeout or M.DEFAULT_TIMEOUT_MS,
  }, function(result)
    vim.schedule(function()
      local raw = vim.fn.filereadable(opts.results_path) == 1 and table.concat(vim.fn.readfile(opts.results_path), '\n')
        or nil

      if not raw then
        local detail = vim.trim((result.stderr or '') .. (result.stdout or ''))
        if detail == '' then
          detail = ('exit %d'):format(result.code)
        end
        return on_done(('rendering failed: %s'):format(detail))
      end

      local parsed, err = results.parse(raw)
      if not parsed then
        return on_done(err)
      end

      on_done(nil, parsed)
    end)
  end)

  if not spawned then
    vim.schedule(function()
      on_done(('failed to start %s: %s'):format(java, tostring(spawn_err)))
    end)
  end
end

return M
