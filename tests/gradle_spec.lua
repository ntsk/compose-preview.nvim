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
  it('マーカーに挟まれた JSON を取り出す', function()
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

  it('複数モジュールのブロックをすべて取り出す', function()
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

  it('マーカーが無ければ nil とエラーを返す', function()
    local infos, err = gradle.parse_info('BUILD FAILED\nSomething went wrong')

    assert.is_nil(infos)
    assert.is_string(err)
  end)

  it('JSON が壊れていれば nil とエラーを返す', function()
    local infos, err = gradle.parse_info('COMPOSE_PREVIEW_INFO_BEGIN\n{ broken\nCOMPOSE_PREVIEW_INFO_END')

    assert.is_nil(infos)
    assert.is_string(err)
  end)

  it('JSON の null を vim.NIL のまま漏らさない', function()
    local infos = gradle.parse_info('COMPOSE_PREVIEW_INFO_BEGIN\n{"project":":app","resourceApkPath":null}\nCOMPOSE_PREVIEW_INFO_END')

    assert.is_nil(infos[1].resourceApkPath)
  end)
end)

describe('gradle.find_project_root', function()
  it('gradlew を持つ最も近い祖先を返す', function()
    local root = tmpdir()
    touch(root .. '/gradlew')
    touch(root .. '/app/src/main/java/Foo.kt')

    assert.are.equal(root, gradle.find_project_root(root .. '/app/src/main/java/Foo.kt'))
  end)

  it('gradlew が無ければ nil を返す', function()
    local dir = tmpdir()
    touch(dir .. '/app/Foo.kt')

    assert.is_nil(gradle.find_project_root(dir .. '/app/Foo.kt'))
  end)
end)

describe('gradle.find_module', function()
  it('build.gradle.kts を持つ最も近い祖先から Gradle パスを組み立てる', function()
    local root = tmpdir()
    touch(root .. '/gradlew')
    touch(root .. '/app/build.gradle.kts')
    touch(root .. '/app/src/main/java/Foo.kt')

    assert.are.equal(':app', gradle.find_module(root, root .. '/app/src/main/java/Foo.kt'))
  end)

  it('ネストしたモジュールはコロン区切りにする', function()
    local root = tmpdir()
    touch(root .. '/gradlew')
    touch(root .. '/feature/home/build.gradle')
    touch(root .. '/feature/home/src/Foo.kt')

    assert.are.equal(':feature:home', gradle.find_module(root, root .. '/feature/home/src/Foo.kt'))
  end)

  it('ルートプロジェクト直下のソースなら空の Gradle パスを返す', function()
    local root = tmpdir()
    touch(root .. '/gradlew')
    touch(root .. '/build.gradle.kts')
    touch(root .. '/src/Foo.kt')

    assert.are.equal('', gradle.find_module(root, root .. '/src/Foo.kt'))
  end)

  it('build.gradle が見つからなければ nil を返す', function()
    local root = tmpdir()
    touch(root .. '/gradlew')
    touch(root .. '/app/src/Foo.kt')

    assert.is_nil(gradle.find_module(root, root .. '/app/src/Foo.kt'))
  end)
end)
