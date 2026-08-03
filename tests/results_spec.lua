local results = require('compose-preview.results')

describe('results.parse', function()
  it('成功したレンダリングを image_path 付きで返す', function()
    local parsed = results.parse([[
      {
        "globalError": null,
        "screenshotResults": [
          {
            "previewId": "com.example.FooKt.Greeting_0",
            "methodFQN": "com.example.FooKt.Greeting",
            "imagePath": "/out/com/example/Greeting_0.png",
            "error": null
          }
        ]
      }
    ]])

    assert.is_nil(parsed.global_error)
    assert.are.equal(1, #parsed.previews)

    local preview = parsed.previews[1]
    assert.are.equal('com.example.FooKt.Greeting_0', preview.preview_id)
    assert.are.equal('com.example.FooKt.Greeting', preview.method_fqn)
    assert.are.equal('/out/com/example/Greeting_0.png', preview.image_path)
    assert.is_true(preview.ok)
    assert.is_nil(preview.error)
  end)

  it('失敗したレンダリングのエラーを正規化する', function()
    local parsed = results.parse([[
      {
        "globalError": null,
        "screenshotResults": [
          {
            "previewId": "com.example.FooKt.Broken_0",
            "methodFQN": "com.example.FooKt.Broken",
            "imagePath": null,
            "error": {
              "status": "ERROR_RENDER_TASK",
              "message": "java.lang.NullPointerException",
              "stackTrace": "at com.example.FooKt.Broken(Foo.kt:12)",
              "problems": [],
              "brokenClasses": [],
              "missingClasses": ["com.example.Missing"]
            }
          }
        ]
      }
    ]])

    local preview = parsed.previews[1]
    assert.is_false(preview.ok)
    assert.is_nil(preview.image_path)
    assert.are.equal('ERROR_RENDER_TASK', preview.error.status)
    assert.are.equal('java.lang.NullPointerException', preview.error.message)
    assert.are.equal('at com.example.FooKt.Broken(Foo.kt:12)', preview.error.stack_trace)
    assert.are.same({ 'com.example.Missing' }, preview.error.missing_classes)
  end)

  it('globalError を取り出す', function()
    local parsed = results.parse([[
      { "globalError": "Layoutlib not found", "screenshotResults": [] }
    ]])

    assert.are.equal('Layoutlib not found', parsed.global_error)
    assert.are.same({}, parsed.previews)
  end)

  it('screenshotResults が欠けていても空リストを返す', function()
    local parsed = results.parse([[ { "globalError": null } ]])

    assert.are.same({}, parsed.previews)
  end)

  it('JSON の null を vim.NIL のまま漏らさない', function()
    local parsed = results.parse([[
      {
        "globalError": null,
        "screenshotResults": [
          {
            "previewId": "a",
            "methodFQN": "b",
            "imagePath": null,
            "error": null
          }
        ]
      }
    ]])

    assert.are_not.equal(vim.NIL, parsed.global_error)
    assert.are_not.equal(vim.NIL, parsed.previews[1].image_path)
    assert.are_not.equal(vim.NIL, parsed.previews[1].error)
  end)

  it('壊れた JSON では nil とエラーメッセージを返す', function()
    local parsed, err = results.parse('{ not json')

    assert.is_nil(parsed)
    assert.is_string(err)
  end)
end)
