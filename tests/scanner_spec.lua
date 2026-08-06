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

  it('has no method_params for a preview without parameters', function()
    local src = [[
package com.example

@Preview
@Composable
fun Greeting() {
}
]]
    assert.are.same({}, scanner.scan(src, 'Foo.kt')[1].method_params)
  end)

  it('resolves a @PreviewParameter provider through imports', function()
    local src = [[
package com.example

import com.example.provider.MyProvider

@Preview
@Composable
fun Greeting(@PreviewParameter(MyProvider::class) state: UiState) {
}
]]
    local previews = scanner.scan(src, 'Foo.kt')

    assert.are.same({ { provider = 'com.example.provider.MyProvider' } }, previews[1].method_params)
  end)

  it('falls back to the file package when the provider is not imported', function()
    local src = [[
package com.example.ui

@Preview
@Composable
fun Greeting(@PreviewParameter(LocalProvider::class) state: UiState) {
}
]]
    local previews = scanner.scan(src, 'Foo.kt')

    assert.are.equal('com.example.ui.LocalProvider', previews[1].method_params[1].provider)
  end)

  it('keeps an already qualified provider reference', function()
    local src = [[
package com.example

@Preview
@Composable
fun Greeting(@PreviewParameter(com.other.Provider::class) state: UiState) {
}
]]
    local previews = scanner.scan(src, 'Foo.kt')

    assert.are.equal('com.other.Provider', previews[1].method_params[1].provider)
  end)

  it('captures the limit argument', function()
    local src = [[
package com.example

@Preview
@Composable
fun Greeting(@PreviewParameter(P::class, limit = 3) state: UiState) {
}
]]
    local previews = scanner.scan(src, 'Foo.kt')

    assert.are.equal('3', previews[1].method_params[1].limit)
  end)

  it('collects one entry per annotated parameter', function()
    local src = [[
package com.example

@Preview
@Composable
fun Greeting(
    @PreviewParameter(A::class) first: X,
    @PreviewParameter(B::class) second: Y,
) {
}
]]
    local previews = scanner.scan(src, 'Foo.kt')

    assert.are.equal(2, #previews[1].method_params)
    assert.are.equal('com.example.A', previews[1].method_params[1].provider)
    assert.are.equal('com.example.B', previews[1].method_params[2].provider)
  end)

  it('ignores parameters without @PreviewParameter', function()
    local src = [[
package com.example

@Preview
@Composable
fun Greeting(plain: String, @PreviewParameter(P::class) state: UiState) {
}
]]
    local previews = scanner.scan(src, 'Foo.kt')

    assert.are.equal(1, #previews[1].method_params)
    assert.are.equal('com.example.P', previews[1].method_params[1].provider)
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
