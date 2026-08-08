# Contributing

Thanks for taking the time to contribute.

## Development setup

```sh
git clone https://github.com/ntsk/compose-preview.nvim
cd compose-preview.nvim
make test
```

The first `make test` clones plenary.nvim and builds a Kotlin treesitter parser
into `.tests/`. Nothing is installed outside the repository.

To try your changes in your own Neovim, point your plugin manager at the working
copy instead of the remote:

```lua
{ dir = vim.fn.expand('~/path/to/compose-preview.nvim'), ft = 'kotlin', opts = {} }
```

## Tests

This project is developed test first. Write a failing test, confirm it fails for
the reason you expect, then make it pass.

```sh
make test                                    # everything
nvim --headless --clean -u tests/minimal_init.lua \
  -c "PlenaryBustedFile tests/scanner_spec.lua"   # one file
```

`PlenaryBustedDirectory` swallows the details when a spec file fails to load, so
run the single-file command when a suite disappears from the output.

The unit tests never touch the network, Gradle, or Java. Anything that does
belongs behind an injected path or option so it stays testable.

## Verifying against a real project

`sample/` is a minimal Compose project used to check the whole pipeline. Open
`sample/app/src/main/java/com/example/sample/Greeting.kt` and run
`:ComposePreview`. Seven cards should render from five `@Preview` declarations.

The sample deliberately exercises the features that are easy to break:

- `@PreviewLightDark`, which must produce visibly different colours because the
  theme reads `isSystemInDarkTheme()`
- several `@Preview` on one function, with `widthDp` changing the layout
- a `@PreviewParameter` provider, which must expand into one card per value

When you change how the renderer is invoked, verify against a project that uses
product flavors and a recent AGP as well. Layouts under `build/intermediates`
differ between AGP versions, and stale directories from older AGP versions are a
recurring source of bugs.

## Style

- Lua is formatted with [StyLua](https://github.com/JohnnyMorganz/StyLua) and
  linted with [luacheck](https://github.com/lunarmodules/luacheck). CI runs both.
- Everything in the repository is written in English.
- Comments explain why, not what. Most code here needs none.

```sh
stylua .
luacheck .
```

## Commits

Keep the subject line short, imperative, capitalized, and under 50 characters.
Add a body only when the change needs explaining.

Do not use `git add -A`. Stage the files you meant to change.

## Toolchain versions

`lua/compose-preview/toolchain.lua` pins the renderer and layoutlib versions.
They are not independent: the `RecyclableImage` ABI changed between layoutlib
17.0.0 and 17.0.1, and renderer alpha16 only works with 17.0.0. If you bump any
of them, render the sample project and confirm the images are real output rather
than the grey broken-class placeholder.

Renovate watches those three constants and opens a single grouped pull request
when any of them moves. **Do not merge such a pull request on CI alone.** CI runs
the Lua tests, which never invoke Gradle or the renderer, so a broken
renderer/layoutlib combination passes every check. Render `sample/` locally and
look at the images before merging.
