local html = require('compose-preview.html')

describe('html.escape', function()
  it('turns HTML special characters into entities', function()
    assert.are.equal('&lt;script&gt;', html.escape('<script>'))
    assert.are.equal('a &amp; b', html.escape('a & b'))
    assert.are.equal('&quot;x&quot;', html.escape('"x"'))
  end)

  it('does not double-escape ampersands', function()
    assert.are.equal('&lt;a&gt; &amp; &lt;b&gt;', html.escape('<a> & <b>'))
  end)
end)

describe('html.build', function()
  local function build(items, opts)
    opts = opts or {}
    opts.title = opts.title or 'Greeting.kt'
    opts.items = items
    return html.build(opts)
  end

  it('shows the title in the heading', function()
    local page = build({})

    assert.is_truthy(page:find('Greeting.kt', 1, true))
  end)

  it('lays out successful previews as img elements', function()
    local page = build({
      { name = 'GreetingPreview', ok = true, image_src = 'out/com/example/GreetingPreview_0_0.png' },
    })

    assert.is_truthy(page:find('src="out/com/example/GreetingPreview_0_0.png"', 1, true))
    assert.is_truthy(page:find('GreetingPreview', 1, true))
  end)

  it('shows an error message and no img for failed previews', function()
    local page = build({
      {
        name = 'BrokenPreview',
        ok = false,
        error = { message = 'java.lang.NullPointerException', stack_trace = 'at Foo.kt:12' },
      },
    })

    assert.is_truthy(page:find('java.lang.NullPointerException', 1, true))
    assert.is_truthy(page:find('at Foo.kt:12', 1, true))
    assert.is_nil(page:find('<img', 1, true))
  end)

  it('escapes HTML in preview names', function()
    local page = build({
      { name = '<script>alert(1)</script>', ok = true, image_src = 'a.png' },
    })

    assert.is_nil(page:find('<script>alert(1)</script>', 1, true))
    assert.is_truthy(page:find('&lt;script&gt;', 1, true))
  end)

  it('escapes HTML in error messages too', function()
    local page = build({
      { name = 'X', ok = false, error = { message = '<img src=x onerror=alert(1)>' } },
    })

    assert.is_nil(page:find('<img src=x', 1, true))
  end)

  it('says so when there are no previews', function()
    local page = build({})

    assert.is_truthy(page:find('@Preview', 1, true))
  end)

  it('surfaces a global error prominently', function()
    local page = build({}, { global_error = 'Layoutlib not found' })

    assert.is_truthy(page:find('Layoutlib not found', 1, true))
  end)

  it('prefers the label over the preview name', function()
    local page = build({
      { name = 'GreetingSizePreview', label = 'Wide', ok = true, image_src = 'a.png' },
    })

    assert.is_truthy(page:find('Wide', 1, true))
  end)

  it('embeds a token for auto reload', function()
    local page = build({}, { token = 'abc123' })

    assert.is_truthy(page:find('abc123', 1, true))
  end)
end)
