local settings = require('compose-preview.settings')

local function opts(previews)
  return {
    previews = previews,
    layoutlib_path = '/cache/layoutlib',
    output_dir = '/work/out',
    metadata_dir = '/work/meta',
    results_path = '/work/results.json',
    namespace = 'com.example.app',
    resource_apk_path = '/work/res.apk',
    class_path = { '/work/classes', '/m2/compose.jar' },
    project_class_path = { '/work/classes' },
  }
end

local function preview(fqn, params)
  return { name = 'X', method_fqn = fqn, line = 1, params = params or {} }
end

describe('settings.build', function()
  it('レンダラが要求するフィールド名にマッピングする', function()
    local result = settings.build(opts({ preview('com.example.app.FooKt.Greeting') }))

    assert.are.equal('/cache/layoutlib', result.layoutlibPath)
    assert.are.equal('/work/out', result.outputFolder)
    assert.are.equal('/work/meta', result.metaDataFolder)
    assert.are.equal('/work/results.json', result.resultsFilePath)
    assert.are.equal('com.example.app', result.namespace)
    assert.are.equal('/work/res.apk', result.resourceApkPath)
    assert.are.same({ '/work/classes', '/m2/compose.jar' }, result.classPath)
    assert.are.same({ '/work/classes' }, result.projectClassPath)
  end)

  it('previews を screenshots に変換する', function()
    local result = settings.build(opts({
      preview('com.example.app.FooKt.Greeting', { showBackground = 'true' }),
    }))

    assert.are.equal(1, #result.screenshots)
    assert.are.equal('com.example.app.FooKt.Greeting', result.screenshots[1].methodFQN)
    assert.are.same({ showBackground = 'true' }, result.screenshots[1].previewParams)
  end)

  it('previewId を methodFQN と連番から組み立てる', function()
    local result = settings.build(opts({ preview('com.example.app.FooKt.Greeting') }))

    assert.are.equal('com.example.app.FooKt.Greeting_0', result.screenshots[1].previewId)
  end)

  it('同一関数の複数 @Preview で previewId が衝突しない', function()
    local result = settings.build(opts({
      preview('com.example.app.FooKt.Greeting', { name = 'Light' }),
      preview('com.example.app.FooKt.Greeting', { name = 'Dark' }),
    }))

    assert.are.equal('com.example.app.FooKt.Greeting_0', result.screenshots[1].previewId)
    assert.are.equal('com.example.app.FooKt.Greeting_1', result.screenshots[2].previewId)
  end)

  it('関数ごとに連番を 0 から振り直す', function()
    local result = settings.build(opts({
      preview('com.example.app.FooKt.A'),
      preview('com.example.app.FooKt.B'),
      preview('com.example.app.FooKt.A'),
    }))

    assert.are.equal('com.example.app.FooKt.A_0', result.screenshots[1].previewId)
    assert.are.equal('com.example.app.FooKt.B_0', result.screenshots[2].previewId)
    assert.are.equal('com.example.app.FooKt.A_1', result.screenshots[3].previewId)
  end)

  it('JSON にエンコードしたとき classPath が配列になる', function()
    local encoded = vim.json.encode(settings.build(opts({ preview('com.example.app.FooKt.Greeting') })))

    assert.is_truthy(encoded:find('"classPath":%["/work/classes","/m2/compose.jar"%]'))
  end)
end)
