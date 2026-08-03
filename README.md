# compose-preview.nvim

Jetpack Compose の `@Preview` を Neovim から描画するプラグイン。

Android Studio と同じ描画エンジン（layoutlib）を standalone で実行し、
生成された PNG をブラウザで一覧表示する。エミュレータも実機も Android Studio も不要。

## 仕組み

```
.kt の @Preview を treesitter で検出
  → Gradle で classpath / リソース APK を解決
  → compose-preview-renderer (layoutlib) を実行
  → PNG + results.json
  → HTML を生成してブラウザで表示
```

描画には Google が公開している以下を使う。いずれも Google Maven から取得でき、
Android Studio のインストールは不要。

| | |
|---|---|
| レンダラ | `com.android.tools.compose:compose-preview-renderer` |
| layoutlib | `com.android.tools.layoutlib:layoutlib-runtime` |

## 開発

```sh
make test
```

初回はテスト用の依存（plenary.nvim / treesitter パーサ）を `.tests/` に取得する。
