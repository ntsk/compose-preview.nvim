local scanner = require('compose-preview.scanner')

describe('scanner.scan', function()
  it('パッケージとファイル名から methodFQN を組み立てる', function()
    local src = [[
package com.example.app

import androidx.compose.runtime.Composable
import androidx.compose.ui.tooling.preview.Preview

@Preview
@Composable
fun Greeting() {
}
]]
    local previews = scanner.scan(src, 'MainActivity.kt')

    assert.are.equal(1, #previews)
    assert.are.equal('Greeting', previews[1].name)
    assert.are.equal('com.example.app.MainActivityKt.Greeting', previews[1].method_fqn)
    assert.are.equal(8, previews[1].line)
  end)

  it('package 宣言が無ければ FQN はファイルクラス名のみになる', function()
    local src = [[
@Preview
@Composable
fun Greeting() {
}
]]
    local previews = scanner.scan(src, 'Foo.kt')

    assert.are.equal(1, #previews)
    assert.are.equal('FooKt.Greeting', previews[1].method_fqn)
  end)

  it('@Preview が無い関数は無視する', function()
    local src = [[
package com.example

@Composable
fun NotAPreview() {
}

fun plain() {
}
]]
    assert.are.same({}, scanner.scan(src, 'Foo.kt'))
  end)

  it('@Preview の引数を params として取り出す', function()
    local src = [[
package com.example

@Preview(name = "Dark", showBackground = true, widthDp = 320)
@Composable
fun Greeting() {
}
]]
    local previews = scanner.scan(src, 'Foo.kt')

    assert.are.equal(1, #previews)
    assert.are.same({
      name = 'Dark',
      showBackground = 'true',
      widthDp = '320',
    }, previews[1].params)
  end)

  it('引数の無い @Preview の params は空テーブルになる', function()
    local src = [[
package com.example

@Preview
@Composable
fun Greeting() {
}
]]
    assert.are.same({}, scanner.scan(src, 'Foo.kt')[1].params)
  end)

  it('複数の @Preview 関数をすべて拾う', function()
    local src = [[
package com.example

@Preview
@Composable
fun First() {
}

@Composable
fun Helper() {
}

@Preview(showBackground = true)
@Composable
fun Second() {
}
]]
    local previews = scanner.scan(src, 'Foo.kt')

    assert.are.equal(2, #previews)
    assert.are.equal('First', previews[1].name)
    assert.are.equal('Second', previews[2].name)
  end)

  it('1つの関数に付いた複数の @Preview をそれぞれ別エントリにする', function()
    local src = [[
package com.example

@Preview(name = "Light")
@Preview(name = "Dark", uiMode = 32)
@Composable
fun Greeting() {
}
]]
    local previews = scanner.scan(src, 'Foo.kt')

    assert.are.equal(2, #previews)
    assert.are.equal('com.example.FooKt.Greeting', previews[1].method_fqn)
    assert.are.equal('com.example.FooKt.Greeting', previews[2].method_fqn)
    assert.are.equal('Light', previews[1].params.name)
    assert.are.equal('Dark', previews[2].params.name)
  end)

  it('スネークケースを含むファイル名でもファイルクラス名を組み立てる', function()
    local src = [[
@Preview
@Composable
fun Greeting() {
}
]]
    local previews = scanner.scan(src, 'my_screen.kt')

    assert.are.equal('My_screenKt.Greeting', previews[1].method_fqn)
  end)
end)
