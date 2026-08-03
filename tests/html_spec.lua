local html = require('compose-preview.html')

describe('html.escape', function()
  it('HTML の特殊文字を実体参照に変換する', function()
    assert.are.equal('&lt;script&gt;', html.escape('<script>'))
    assert.are.equal('a &amp; b', html.escape('a & b'))
    assert.are.equal('&quot;x&quot;', html.escape('"x"'))
  end)

  it('アンパサンドを二重変換しない', function()
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

  it('タイトルを見出しに出す', function()
    local page = build({})

    assert.is_truthy(page:find('Greeting.kt', 1, true))
  end)

  it('成功したプレビューを img として並べる', function()
    local page = build({
      { name = 'GreetingPreview', ok = true, image_src = 'out/com/example/GreetingPreview_0_0.png' },
    })

    assert.is_truthy(page:find('src="out/com/example/GreetingPreview_0_0.png"', 1, true))
    assert.is_truthy(page:find('GreetingPreview', 1, true))
  end)

  it('失敗したプレビューはエラーメッセージを出し img を出さない', function()
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

  it('プレビュー名の HTML をエスケープする', function()
    local page = build({
      { name = '<script>alert(1)</script>', ok = true, image_src = 'a.png' },
    })

    assert.is_nil(page:find('<script>alert(1)</script>', 1, true))
    assert.is_truthy(page:find('&lt;script&gt;', 1, true))
  end)

  it('エラーメッセージの HTML もエスケープする', function()
    local page = build({
      { name = 'X', ok = false, error = { message = '<img src=x onerror=alert(1)>' } },
    })

    assert.is_nil(page:find('<img src=x', 1, true))
  end)

  it('プレビューが 0 件ならその旨を出す', function()
    local page = build({})

    assert.is_truthy(page:find('@Preview', 1, true))
  end)

  it('全体エラーがあれば目立つ位置に出す', function()
    local page = build({}, { global_error = 'Layoutlib not found' })

    assert.is_truthy(page:find('Layoutlib not found', 1, true))
  end)

  it('ラベルがあればプレビュー名の代わりに使う', function()
    local page = build({
      { name = 'GreetingSizePreview', label = 'Wide', ok = true, image_src = 'a.png' },
    })

    assert.is_truthy(page:find('Wide', 1, true))
  end)

  it('自動リロード用のトークンを埋め込む', function()
    local page = build({}, { token = 'abc123' })

    assert.is_truthy(page:find('abc123', 1, true))
  end)
end)
