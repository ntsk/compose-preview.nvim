local renderer = require('compose-preview.renderer')
local toolchain = require('compose-preview.toolchain')

local M = {}

M.MINIMUM_NVIM = '0.11.0'

local REQUIRED_EXECUTABLES = { 'curl', 'unzip' }

function M.evaluate(env)
  local results = {}

  local function add(name, status, message, advice)
    table.insert(results, { name = name, status = status, message = message, advice = advice })
  end

  if env.windows then
    add('os', 'error', 'Windows is not supported', 'run Neovim inside WSL, where the plugin works as on Linux')
  else
    add('os', 'ok', 'running on a supported operating system')
  end

  if env.nvim_supported then
    add('neovim', 'ok', ('Neovim %s or newer'):format(M.MINIMUM_NVIM))
  else
    add('neovim', 'error', ('Neovim %s or newer is required'):format(M.MINIMUM_NVIM))
  end

  if not env.java then
    add(
      'java',
      'error',
      ('no Java %d or newer found'):format(renderer.MINIMUM_JAVA_VERSION),
      'install a JDK 21+ and make it discoverable, or set the java option to an absolute path'
    )
  elseif (env.java_version or 0) < renderer.MINIMUM_JAVA_VERSION then
    add(
      'java',
      'error',
      ('found Java %d at %s, but %d or newer is required'):format(
        env.java_version or 0,
        env.java,
        renderer.MINIMUM_JAVA_VERSION
      ),
      'set the java option to an absolute path to a JDK 21+'
    )
  else
    add('java', 'ok', ('Java %d at %s'):format(env.java_version, env.java))
  end

  if env.kotlin_parser then
    add('treesitter', 'ok', 'the kotlin parser is available')
  else
    add(
      'treesitter',
      'error',
      'the kotlin treesitter parser is not available',
      'install the kotlin parser however you manage treesitter parsers, and make sure it is on the runtimepath'
    )
  end

  for _, name in ipairs(REQUIRED_EXECUTABLES) do
    if env.executables[name] then
      add(name, 'ok', ('%s is executable'):format(name))
    else
      add(name, 'error', ('%s was not found on PATH'):format(name), ('install %s'):format(name))
    end
  end

  if env.toolchain_installed then
    add('toolchain', 'ok', ('the renderer toolchain is installed in %s'):format(env.cache_dir))
  else
    add('toolchain', 'ok', ('the renderer toolchain will download into %s on first use'):format(env.cache_dir))
  end

  return results
end

local function java_version_of(path)
  local ok, result = pcall(function()
    return vim.system({ path, '-version' }, { text = true }):wait()
  end)

  if not ok or result.code ~= 0 then
    return nil
  end

  return renderer.parse_java_version((result.stderr or '') .. (result.stdout or ''))
end

local function kotlin_parser_available()
  return pcall(vim.treesitter.get_string_parser, '', 'kotlin')
end

function M.probe(config)
  config = config or {}
  local java = config.java or renderer.find_java()
  local executables = {}

  for _, name in ipairs(REQUIRED_EXECUTABLES) do
    executables[name] = vim.fn.executable(name) == 1
  end

  return {
    nvim_supported = vim.fn.has('nvim-' .. M.MINIMUM_NVIM) == 1,
    windows = vim.fn.has('win32') == 1,
    java = java,
    java_version = java and java_version_of(java) or nil,
    kotlin_parser = kotlin_parser_available(),
    executables = executables,
    toolchain_installed = toolchain.is_installed({ cache_dir = config.cache_dir }),
    cache_dir = toolchain.paths({ cache_dir = config.cache_dir }).cache_dir,
  }
end

function M.check()
  vim.health.start('compose-preview.nvim')

  local config = require('compose-preview').config

  for _, result in ipairs(M.evaluate(M.probe(config))) do
    local text = ('%s: %s'):format(result.name, result.message)
    if result.status == 'ok' then
      vim.health.ok(text)
    elseif result.status == 'warn' then
      vim.health.warn(text, result.advice and { result.advice } or nil)
    else
      vim.health.error(text, result.advice and { result.advice } or nil)
    end
  end
end

return M
