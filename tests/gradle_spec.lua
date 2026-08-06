local gradle = require('compose-preview.gradle')

local function tmpdir()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, 'p')
  return dir
end

local function touch(path)
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  vim.fn.writefile({ '' }, path)
end

describe('gradle.parse_info', function()
  it('extracts the JSON between the markers', function()
    local infos = gradle.parse_info(table.concat({
      'Starting a Gradle Daemon',
      'COMPOSE_PREVIEW_INFO_BEGIN',
      '{"project":":app","namespace":"com.example","classPath":["/a.jar"],"projectClassPath":["/c"],"resourceApkPath":"/r.ap_"}',
      'COMPOSE_PREVIEW_INFO_END',
      'BUILD SUCCESSFUL',
    }, '\n'))

    assert.are.equal(1, #infos)
    assert.are.equal(':app', infos[1].project)
    assert.are.equal('com.example', infos[1].namespace)
    assert.are.same({ '/a.jar' }, infos[1].classPath)
    assert.are.equal('/r.ap_', infos[1].resourceApkPath)
  end)

  it('extracts a block for every module', function()
    local infos = gradle.parse_info(table.concat({
      'COMPOSE_PREVIEW_INFO_BEGIN',
      '{"project":":app","namespace":"com.example.app"}',
      'COMPOSE_PREVIEW_INFO_END',
      'COMPOSE_PREVIEW_INFO_BEGIN',
      '{"project":":core","namespace":"com.example.core"}',
      'COMPOSE_PREVIEW_INFO_END',
    }, '\n'))

    assert.are.equal(2, #infos)
    assert.are.equal(':app', infos[1].project)
    assert.are.equal(':core', infos[2].project)
  end)

  it('returns nil and an error when the markers are absent', function()
    local infos, err = gradle.parse_info('BUILD FAILED\nSomething went wrong')

    assert.is_nil(infos)
    assert.is_string(err)
  end)

  it('returns nil and an error when the JSON is broken', function()
    local infos, err = gradle.parse_info('COMPOSE_PREVIEW_INFO_BEGIN\n{ broken\nCOMPOSE_PREVIEW_INFO_END')

    assert.is_nil(infos)
    assert.is_string(err)
  end)

  it('never leaks JSON null as vim.NIL', function()
    local infos = gradle.parse_info('COMPOSE_PREVIEW_INFO_BEGIN\n{"project":":app","resourceApkPath":null}\nCOMPOSE_PREVIEW_INFO_END')

    assert.is_nil(infos[1].resourceApkPath)
  end)
end)

describe('gradle.command', function()
  local function opts(extra)
    return vim.tbl_extend('force', {
      root = '/proj',
      module = ':app',
      init_script = '/plugin/init.gradle',
    }, extra or {})
  end

  it('runs only composePreviewInfo', function()
    local cmd = gradle.command(opts())

    assert.are.equal('/proj/gradlew', cmd[1])
    assert.is_truthy(vim.tbl_contains(cmd, ':app:composePreviewInfo'))
    assert.is_truthy(vim.tbl_contains(cmd, '--init-script'))
    assert.is_truthy(vim.tbl_contains(cmd, '/plugin/init.gradle'))
  end)

  it('omits composePreviewVariant when no variant is given', function()
    for _, arg in ipairs(gradle.command(opts())) do
      assert.is_nil(arg:match('composePreviewVariant'))
    end
  end)

  it('passes the variant as a Gradle property', function()
    local cmd = gradle.command(opts({ variant = 'devDebug' }))

    assert.is_truthy(vim.tbl_contains(cmd, '-PcomposePreviewVariant=devDebug'))
  end)

  it('uses a bare colon task name for the root module', function()
    local cmd = gradle.command(opts({ module = '' }))

    assert.is_truthy(vim.tbl_contains(cmd, ':composePreviewInfo'))
  end)
end)

describe('gradle.describe_variant_error', function()
  it('lists the candidate variants', function()
    local message = gradle.describe_variant_error('debug', { 'devDebug', 'productionDebug' })

    assert.is_truthy(message:find('debug', 1, true))
    assert.is_truthy(message:find('devDebug', 1, true))
    assert.is_truthy(message:find('productionDebug', 1, true))
  end)
end)

describe('gradle.find_project_root', function()
  it('returns the nearest ancestor holding gradlew', function()
    local root = tmpdir()
    touch(root .. '/gradlew')
    touch(root .. '/app/src/main/java/Foo.kt')

    assert.are.equal(root, gradle.find_project_root(root .. '/app/src/main/java/Foo.kt'))
  end)

  it('returns nil when there is no gradlew', function()
    local dir = tmpdir()
    touch(dir .. '/app/Foo.kt')

    assert.is_nil(gradle.find_project_root(dir .. '/app/Foo.kt'))
  end)
end)

describe('gradle.find_module', function()
  it('builds the Gradle path from the nearest ancestor holding build.gradle.kts', function()
    local root = tmpdir()
    touch(root .. '/gradlew')
    touch(root .. '/app/build.gradle.kts')
    touch(root .. '/app/src/main/java/Foo.kt')

    assert.are.equal(':app', gradle.find_module(root, root .. '/app/src/main/java/Foo.kt'))
  end)

  it('joins nested modules with colons', function()
    local root = tmpdir()
    touch(root .. '/gradlew')
    touch(root .. '/feature/home/build.gradle')
    touch(root .. '/feature/home/src/Foo.kt')

    assert.are.equal(':feature:home', gradle.find_module(root, root .. '/feature/home/src/Foo.kt'))
  end)

  it('returns an empty Gradle path for sources directly under the root project', function()
    local root = tmpdir()
    touch(root .. '/gradlew')
    touch(root .. '/build.gradle.kts')
    touch(root .. '/src/Foo.kt')

    assert.are.equal('', gradle.find_module(root, root .. '/src/Foo.kt'))
  end)

  it('returns nil when no build.gradle is found', function()
    local root = tmpdir()
    touch(root .. '/gradlew')
    touch(root .. '/app/src/Foo.kt')

    assert.is_nil(gradle.find_module(root, root .. '/app/src/Foo.kt'))
  end)
end)
