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

describe('gradle.read_info', function()
  local function write(contents)
    local path = vim.fn.tempname()
    vim.fn.writefile(vim.split(contents, '\n'), path)
    return path
  end

  it('decodes the JSON the init script wrote', function()
    local path = write('{"project":":app","namespace":"com.example","classPath":["/a.jar"]}')

    local info = gradle.read_info(path)

    assert.are.equal(':app', info.project)
    assert.are.equal('com.example', info.namespace)
    assert.are.same({ '/a.jar' }, info.classPath)
  end)

  it('returns nil and an error when the file is missing', function()
    local info, err = gradle.read_info(vim.fn.tempname())

    assert.is_nil(info)
    assert.is_string(err)
  end)

  it('returns nil and an error when the JSON is broken', function()
    local info, err = gradle.read_info(write('{ broken'))

    assert.is_nil(info)
    assert.is_string(err)
  end)

  it('never leaks JSON null as vim.NIL', function()
    local info = gradle.read_info(write('{"project":":app","resourceApkPath":null}'))

    assert.is_nil(info.resourceApkPath)
  end)
end)

describe('gradle.task_line', function()
  it('extracts the task name from a Gradle task line', function()
    assert.are.equal(':app:compileDevDebugKotlin', gradle.task_line('> Task :app:compileDevDebugKotlin'))
  end)

  it('ignores the trailing status', function()
    assert.are.equal(':app:processDebugResources', gradle.task_line('> Task :app:processDebugResources UP-TO-DATE'))
  end)

  it('returns nil for other output', function()
    assert.is_nil(gradle.task_line('BUILD SUCCESSFUL in 4s'))
    assert.is_nil(gradle.task_line('> Configure project :app'))
    assert.is_nil(gradle.task_line(''))
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

describe('gradle.needs_newer_jvm', function()
  it('detects the dependency JVM requirement message', function()
    local result = {
      stderr = table.concat({
        'FAILURE: Build failed with an exception.',
        '> Dependency requires at least JVM runtime version 21. This build uses a Java 17 JVM.',
      }, '\n'),
    }

    assert.is_true(gradle.needs_newer_jvm(result))
  end)

  it('detects the "run this build using a Java N or newer JVM" hint', function()
    local result = { stderr = '> Run this build using a Java 21 or newer JVM.' }

    assert.is_true(gradle.needs_newer_jvm(result))
  end)

  it('detects an unsupported class file version', function()
    local result = { stdout = 'Unsupported class file major version 65' }

    assert.is_true(gradle.needs_newer_jvm(result))
  end)

  it('is false for unrelated failures', function()
    local result = { stderr = "> Task 'composePreviewInfo' not found in project ':app'." }

    assert.is_false(gradle.needs_newer_jvm(result))
  end)

  it('is false when there is no output at all', function()
    assert.is_false(gradle.needs_newer_jvm({}))
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
