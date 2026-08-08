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

```sh
make e2e
```

renders `sample/` for real and checks the output. It needs a JDK 21+, the Android
SDK and the network, which is why it is a separate target. Run it when you change
how Gradle is invoked, how the renderer is called, or the pinned versions.

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
product flavors as well.

`sample/` tracks the current Android Gradle Plugin, which means the code paths
for older ones are not exercised by CI. `gradle/compose-preview.init.gradle`
looks for the generated R classes in three places because the directory moved
between AGP versions, and a stale directory left behind by an older AGP is a
recurring source of bugs. Only the first of those three is covered here, so take
care when touching that lookup.

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

`lua/compose-preview/toolchain.lua` pins the renderer and layoutlib versions, and
is the only place they appear. They are not independent: the renderer only works
with the layoutlib it was built against, so bump them together and confirm the
sample still renders real images rather than the grey broken-class placeholder.

This has bitten before. When layoutlib 17.0.1 appeared, it changed the
`RecyclableImage` ABI and stopped working with the renderer of the day, which
failed with `AbstractMethodError` at render time and nowhere earlier.

Renovate watches those three constants and opens a single grouped pull request
when any of them moves. The `render sample` CI job covers those pull requests: it
runs `make e2e`, which renders `sample/` for real and fails when a preview comes
back as a broken-class placeholder. Its toolchain cache is keyed on
`toolchain.lua`, so a version bump misses the cache and downloads exactly the
versions being proposed.
