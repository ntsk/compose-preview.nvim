# compose-preview.nvim

Render Jetpack Compose `@Preview` from Neovim.

It runs the same rendering engine Android Studio uses (layoutlib) standalone and
shows the resulting PNGs in your browser. No emulator, no device, no Android Studio.

## How it works

```
find @Preview in the .kt buffer with treesitter
  -> resolve classpath and resource APK through Gradle
  -> run compose-preview-renderer (layoutlib)
  -> PNG + results.json
  -> generate HTML and open it in a browser
```

Rendering uses the artifacts Google publishes below. All of them come from Google
Maven, so an Android Studio installation is not needed. They are downloaded into
`~/.cache/nvim/compose-preview` on first use (about 300 MB).

| artifact | version | purpose |
|---|---|---|
| `com.android.tools.compose:compose-preview-renderer` | 0.0.1-alpha16 | the renderer itself |
| `com.android.tools.layoutlib:layoutlib` | 17.0.0 | Android framework classes |
| `com.android.tools.layoutlib:layoutlib-runtime` | 17.0.1 | native libraries and fonts |
| `com.android.tools.layoutlib:layoutlib-resources` | 17.0.1 | framework resources |

The `RecyclableImage` ABI changed between layoutlib 17.0.0 and 17.0.1. Renderer
alpha16 only works with **17.0.0**, so the versions above are not interchangeable.

## Requirements

- Neovim 0.11 or newer
- The `kotlin` treesitter parser
- **Java 21 or newer** (layoutlib is built as class file 65.0)
- A Compose project with the Android SDK and a Gradle wrapper

## Usage

Open a `.kt` file containing `@Preview` and run `:ComposePreview`.

```lua
require('compose-preview').setup({
  variant = nil,           -- build variant; auto-detected when nil
  java = nil,              -- path to java; a Java 21+ JDK is detected when nil
  gradle_java_home = nil,  -- JAVA_HOME for Gradle; inherited from the environment when nil
  open_cmd = nil,          -- command to open the page; vim.ui.open when nil
  cache_dir = nil,         -- toolchain cache; stdpath('cache')/compose-preview when nil
  timeout = 180000,        -- renderer timeout in milliseconds
})
```

Every `@Preview` on a function becomes its own card. `@Preview(name = "...")` is
used as the card heading. Previews that fail to render show their error message
and stack trace in place, so one broken preview does not hide the others.

### Build variant

The variant is detected from the Gradle tasks the project actually defines, so
projects with product flavors work without configuration. Set `variant` when you
want a specific one:

```lua
require('compose-preview').setup({ variant = 'productionDebug' })
```

If the configured variant does not exist, the error lists the available ones.

### Java

Gradle first runs with whatever `JAVA_HOME` Neovim inherited. If the build fails
because the project needs a newer JVM, it is retried once with the Java 21+ JDK
that was detected for the renderer. Set `gradle_java_home` to pin it yourself.

## Troubleshooting

`:ComposePreviewLog` opens the log, which records every step, the exact Gradle
command, and the full Gradle output on failure. Notifications only show the first
error line, so the log is the place to look.

Some `@Preview` attributes cannot be resolved without a full Kotlin frontend.
Constants such as `Configuration.UI_MODE_NIGHT_YES`, hex literals, and `or`
expressions are resolved, but project-specific constants are not. Unresolvable
numeric attributes are dropped for that preview and reported in the log as `WARN`.

## Development

```sh
make test
```

The first run fetches the test dependencies (plenary.nvim and a Kotlin treesitter
parser) into `.tests/`.

`sample/` is a minimal Compose project used to verify the plugin end to end.
