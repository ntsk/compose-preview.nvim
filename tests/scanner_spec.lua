local scanner = require('compose-preview.scanner')

describe('scanner.scan', function()
  it('builds methodFQN from package and file name', function()
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

  it('uses only the file class name when there is no package declaration', function()
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

  it('ignores functions without @Preview', function()
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

  it('extracts @Preview arguments as params', function()
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

  it('yields an empty params table for a bare @Preview', function()
    local src = [[
package com.example

@Preview
@Composable
fun Greeting() {
}
]]
    assert.are.same({}, scanner.scan(src, 'Foo.kt')[1].params)
  end)

  it('picks up every @Preview function', function()
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

  it('emits a separate entry per @Preview on one function', function()
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

  it('builds the file class name for snake_case file names', function()
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
