# AGENTS.md

このファイルはこのリポジトリで作業する AI エージェント（Claude Code、Codex など）と開発者向けのガイドです。
`CLAUDE.md` はこのファイルへのシンボリックリンクなので、編集するのは `AGENTS.md` だけにしてください。

## プロジェクト概要

SevenFour は 2005〜2006 年頃に書かれた macOS 用 2ch ブラウザ（Cocoa / Objective-C）です。
このリポジトリでは、それを **macOS 26 以降の Apple silicon (arm64) と Intel (x86_64)** で動かせるように保守しています。

- 言語: Objective-C（**手動参照カウント / MRC**。ARC は無効）
- UI: 旧形式の Interface Builder `.nib`（`SevenFour/Japanese.lproj/*.nib`、keyedobjects 形式）
- 表示: WebKit の旧 `WebView`（WebKit1）+ `SevenFour/Skin/` の HTML/CSS/JS
- 保存: SQLite（`~/Library/Application Support/SevenFour/Index.db`）

## ディレクトリ構成

```
project.yml              XcodeGen のプロジェクト定義（Xcode プロジェクトはここから生成する）
SevenFour/               アプリ本体のソースとリソース
  *.h / *.m              アプリのソース
  Compat/OgreKit/        OgreKit.framework の互換シム（NSRegularExpression ベース）
  Compat/QuickLite/      QuickLite.framework の互換シム（libsqlite3 ベース）
  Japanese.lproj/        nib、Localizable.strings、Toolbar.plist
  English.lproj/         Credits.rtf、InfoPlist.strings
  Skin/                  スレッド表示用 HTML テンプレート（フォルダごと Resources/Skin にコピー）
  Info.plist             アプリの Info.plist
  SevenFour_Prefix.pch   プレフィックスヘッダ
```

## ビルド

Xcode プロジェクト（`SevenFour.xcodeproj`）は **XcodeGen で生成する** ので、コミットしません（`.gitignore` 済み）。
`.xcodeproj` を直接編集せず、設定の変更は必ず `project.yml` で行ってください。

```sh
brew install xcodegen          # 未インストールの場合
xcodegen generate              # SevenFour.xcodeproj を生成

# Universal (arm64 + x86_64) の Release ビルド
xcodebuild -project SevenFour.xcodeproj -scheme SevenFour \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath build build

# アーキテクチャの確認
lipo -info build/Build/Products/Release/SevenFour.app/Contents/MacOS/SevenFour
```

- デプロイメントターゲットは macOS 26.0、`ARCHS = $(ARCHS_STANDARD)`（arm64 + x86_64）です。
- Debug 構成は `ONLY_ACTIVE_ARCH = YES` です。Universal バイナリを確認するときは上のように Release + `generic/platform=macOS` を使ってください。
- 署名はローカル実行用のアドホック署名（`CODE_SIGN_IDENTITY = "-"`）です。
- ソースやリソースを追加・削除・移動したら `xcodegen generate` を再実行してください。`SevenFour/` 以下のファイルは自動で取り込まれます。

## コーディング上の注意

- **MRC のまま維持すること。** `retain` / `release` / `autorelease` / `dealloc` のバランスに注意してください。ARC は有効にしないでください（`CLANG_ENABLE_OBJC_ARC: NO`）。
- 外部フレームワーク（OgreKit、QuickLite）は使えません。`#import <OgreKit/OgreKit.h>` や `#import <QuickLite/...>` は `SevenFour/Compat/` のシムが解決します（`HEADER_SEARCH_PATHS`）。
  - OgreKit シム: Ruby 構文の OgreKit と同様に `^` / `$` は行単位でマッチし、置換文字列の `\0`〜`\9` はキャプチャグループを表します。
  - QuickLite シム: 列には `"subject"` と `"threads.subject"` のどちらの名前でもアクセスできます。`QuickLiteCursor -save` は ROWID を使って `UPDATE` します（単一テーブルの `SELECT` で取得したカーソルのみ対応）。値はバインドされるので、`setValue:forColumn:` に渡す文字列を `prepareStringForQuery:` でエスケープしないでください。
  - 新しい API が必要な場合は、シムに実装を足すか、標準 API（`NSRegularExpression`、`sqlite3`）を直接使ってください。
- 現行 SDK で削除された API（`NSMenuView`、`-[NSFont defaultLineHeightForFont]` など）は代替 API に置き換えてください。非推奨（deprecated）なだけの API はそのまま使えます。
- `.nib` は旧形式のバイナリなので、テキストとして編集できません。UI を変えるときは、コードで変更するか `.xib` への移行を検討してください。
- ソースのエンコーディングは UTF-8 です。
- **通信は HTTPS 前提です。** 現行 SDK では App Transport Security (ATS) が有効なため、平文 HTTP の通信はブロックされます。ATS の例外は設定していません。
  - 板一覧のデフォルトは `https://menu.5ch.io/bbsmenu.html` です（`SFAppController.m`）。
  - 板・スレッド・DAT の URL を組み立てるときは `http://` を直接書かず、プレフィックスヘッダの `SFSchemeOfURL()`（http と明示されていなければ https）と `SFIsWebURL()` を使ってください。
  - 内部 URL `sevenfour://host/...` はスキームを持たないので、板の URL へ戻すときは https として扱います（`SFURLProtocol.m`）。
  - HTTP でしか提供されていない画像（スレッド内のリンク）や板は、ATS により読み込めません。

## 動作確認

```sh
open build/Build/Products/Release/SevenFour.app
```

- 起動するとメインウィンドウ（スレッド一覧・タブ付き WebView）とサイドドロワー（板一覧）が表示されれば OK です。
- 自動テストはありません。変更後は少なくとも Universal ビルドが通ること、arm64 で起動することを確認してください。
- Intel 版は Intel Mac、または Rosetta 2 が入った Apple silicon Mac で `arch -x86_64 .../SevenFour` を実行して確認します。
