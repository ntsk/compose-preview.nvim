local results = require('compose-preview.results')

describe('results.parse', function()
  it('returns successful renders with image_path', function()
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

  it('normalizes errors from failed renders', function()
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

  it('extracts globalError', function()
    local parsed = results.parse([[
      { "globalError": "Layoutlib not found", "screenshotResults": [] }
    ]])

    assert.are.equal('Layoutlib not found', parsed.global_error)
    assert.are.same({}, parsed.previews)
  end)

  it('returns an empty list when screenshotResults is missing', function()
    local parsed = results.parse([[ { "globalError": null } ]])

    assert.are.same({}, parsed.previews)
  end)

  it('never leaks JSON null as vim.NIL', function()
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

  it('keeps render problems, stripping HTML from their text', function()
    local parsed = results.parse([[
      {
        "screenshotResults": [
          {
            "previewId": "a",
            "methodFQN": "b",
            "imagePath": null,
            "error": {
              "status": "ERROR_NOT_INFLATED",
              "message": "",
              "stackTrace": "",
              "problems": [
                {
                  "html": "Exception raised during rendering: uiState is null (<A HREF=\"\">Details</A>)",
                  "stackTrace": "at Foo.kt:1"
                }
              ],
              "brokenClasses": [],
              "missingClasses": []
            }
          }
        ]
      }
    ]])

    local problems = parsed.previews[1].error.problems
    assert.are.equal(1, #problems)
    assert.are.equal('Exception raised during rendering: uiState is null (Details)', problems[1].message)
    assert.are.equal('at Foo.kt:1', problems[1].stack_trace)
  end)

  it('falls back to the first problem when message is empty', function()
    local parsed = results.parse([[
      {
        "screenshotResults": [
          {
            "previewId": "a",
            "methodFQN": "b",
            "error": {
              "status": "ERROR_NOT_INFLATED",
              "message": "",
              "problems": [{ "html": "uiState is null", "stackTrace": "" }]
            }
          }
        ]
      }
    ]])

    assert.are.equal('uiState is null', parsed.previews[1].error.message)
  end)

  it('falls back to the status when there is nothing else', function()
    local parsed = results.parse([[
      {
        "screenshotResults": [
          { "previewId": "a", "methodFQN": "b", "error": { "status": "ERROR_NOT_INFLATED", "message": "" } }
        ]
      }
    ]])

    assert.are.equal('ERROR_NOT_INFLATED', parsed.previews[1].error.message)
  end)

  it('returns nil and an error message for broken JSON', function()
    local parsed, err = results.parse('{ not json')

    assert.is_nil(parsed)
    assert.is_string(err)
  end)
end)
