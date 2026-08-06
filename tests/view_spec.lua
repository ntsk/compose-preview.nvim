local settings = require('compose-preview.settings')
local view = require('compose-preview.view')

local function preview(fqn, params, name)
  return { name = name or 'X', method_fqn = fqn, line = 1, params = params or {} }
end

describe('settings.preview_ids', function()
  it('matches the previewId order and values used in screenshots', function()
    local previews = {
      preview('com.example.FooKt.A'),
      preview('com.example.FooKt.A'),
      preview('com.example.FooKt.B'),
    }

    local ids = settings.preview_ids(previews)
    local built = settings.build({
      previews = previews,
      class_path = {},
      project_class_path = {},
    })

    assert.are.equal(3, #ids)
    for index, screenshot in ipairs(built.screenshots) do
      assert.are.equal(screenshot.previewId, ids[index])
    end
  end)
end)

describe('view.items', function()
  it('matches results by previewId and builds the relative image path', function()
    local previews = { preview('com.example.FooKt.Greeting', {}, 'Greeting') }
    local results = {
      previews = {
        {
          preview_id = 'com.example.FooKt.Greeting_0',
          image_path = 'com/example/FooKt/Greeting_0_0.png',
          ok = true,
        },
      },
    }

    local items = view.items(previews, results, 'out')

    assert.are.equal(1, #items)
    assert.is_true(items[1].ok)
    assert.are.equal('out/com/example/FooKt/Greeting_0_0.png', items[1].image_src)
  end)

  it('uses the @Preview name as the label', function()
    local previews = { preview('com.example.FooKt.Greeting', { name = 'Dark' }, 'Greeting') }
    local results = { previews = {} }

    assert.are.equal('Dark', view.items(previews, results, 'out')[1].label)
  end)

  it('falls back to the function name as the label', function()
    local previews = { preview('com.example.FooKt.Greeting', {}, 'Greeting') }
    local results = { previews = {} }

    assert.are.equal('Greeting', view.items(previews, results, 'out')[1].label)
  end)

  it('keeps each @Preview on one function as its own item', function()
    local previews = {
      preview('com.example.FooKt.G', { name = 'Light' }, 'G'),
      preview('com.example.FooKt.G', { name = 'Dark' }, 'G'),
    }
    local results = {
      previews = {
        { preview_id = 'com.example.FooKt.G_0', image_path = 'a.png', ok = true },
        { preview_id = 'com.example.FooKt.G_1', image_path = 'b.png', ok = true },
      },
    }

    local items = view.items(previews, results, 'out')

    assert.are.equal('Light', items[1].label)
    assert.are.equal('out/a.png', items[1].image_src)
    assert.are.equal('Dark', items[2].label)
    assert.are.equal('out/b.png', items[2].image_src)
  end)

  it('treats a preview with no matching result as failed', function()
    local previews = { preview('com.example.FooKt.Greeting', {}, 'Greeting') }
    local items = view.items(previews, { previews = {} }, 'out')

    assert.is_false(items[1].ok)
    assert.is_string(items[1].error.message)
  end)

  it('carries the render error through unchanged', function()
    local previews = { preview('com.example.FooKt.Greeting', {}, 'Greeting') }
    local results = {
      previews = {
        {
          preview_id = 'com.example.FooKt.Greeting_0',
          ok = false,
          error = { message = 'NPE', stack_trace = 'at Foo.kt:1' },
        },
      },
    }

    local item = view.items(previews, results, 'out')[1]

    assert.is_false(item.ok)
    assert.are.equal('NPE', item.error.message)
    assert.is_nil(item.image_src)
  end)
end)
