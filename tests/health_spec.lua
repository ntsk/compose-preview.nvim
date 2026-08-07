local health = require('compose-preview.health')

local function env(overrides)
  return vim.tbl_extend('force', {
    nvim_supported = true,
    java = '/jdk21/bin/java',
    java_version = 21,
    kotlin_parser = true,
    executables = { curl = true, unzip = true },
    toolchain_installed = true,
    cache_dir = '/cache',
  }, overrides or {})
end

local function by_name(results)
  local map = {}
  for _, result in ipairs(results) do
    map[result.name] = result
  end
  return map
end

describe('health.evaluate', function()
  it('reports every check with a name and a status', function()
    for _, result in ipairs(health.evaluate(env())) do
      assert.is_string(result.name)
      assert.is_truthy(result.status == 'ok' or result.status == 'warn' or result.status == 'error')
      assert.is_string(result.message)
    end
  end)

  it('is all ok on a healthy setup', function()
    for _, result in ipairs(health.evaluate(env())) do
      assert.are.equal('ok', result.status)
    end
  end)

  it('errors when java is missing', function()
    local without_java = env()
    without_java.java, without_java.java_version = nil, nil

    local result = by_name(health.evaluate(without_java)).java

    assert.are.equal('error', result.status)
    assert.is_string(result.advice)
  end)

  it('errors when java is too old and names the version found', function()
    local result = by_name(health.evaluate(env({ java_version = 17 }))).java

    assert.are.equal('error', result.status)
    assert.is_truthy(result.message:find('17', 1, true))
    assert.is_truthy(result.message:find('21', 1, true))
  end)

  it('errors when the kotlin parser is missing', function()
    local result = by_name(health.evaluate(env({ kotlin_parser = false })))['treesitter']

    assert.are.equal('error', result.status)
    assert.is_string(result.advice)
  end)

  it('errors when a required executable is missing', function()
    local result = by_name(health.evaluate(env({ executables = { curl = false, unzip = true } }))).curl

    assert.are.equal('error', result.status)
  end)

  it('reports an unsupported Neovim version as an error', function()
    local result = by_name(health.evaluate(env({ nvim_supported = false })))['neovim']

    assert.are.equal('error', result.status)
  end)

  it('treats a missing toolchain as ok because it downloads on demand', function()
    local result = by_name(health.evaluate(env({ toolchain_installed = false }))).toolchain

    assert.are.equal('ok', result.status)
    assert.is_truthy(result.message:find('download', 1, true))
  end)
end)
