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
Android Studio のインストールは不要。初回に `~/.cache/nvim/compose-preview` へ展開する。

| artifact | 版 | 用途 |
|---|---|---|
| `com.android.tools.compose:compose-preview-renderer` | 0.0.1-alpha16 | レンダラ本体 |
| `com.android.tools.layoutlib:layoutlib` | 17.0.0 | Android フレームワークのクラス |
| `com.android.tools.layoutlib:layoutlib-runtime` | 17.0.1 | ネイティブライブラリとフォント |
| `com.android.tools.layoutlib:layoutlib-resources` | 17.0.1 | framework リソース |

layoutlib は 17.0.0 と 17.0.1 で `RecyclableImage` の ABI が変わっており、
レンダラ alpha16 と組み合わせて動くのは **17.0.0** の方。

## 必要なもの

- Neovim 0.11 以降
- **Java 21 以降**（layoutlib は class file 65.0 でビルドされている）
- Android SDK と Gradle wrapper を持つ Compose プロジェクト

## 開発

```sh
make test
```

初回はテスト用の依存（plenary.nvim / treesitter パーサ）を `.tests/` に取得する。
