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
Tests/                   XCTest の単体テスト（ターゲット SevenFourTests）
  Fixtures/              テスト用の合成データ（UTF-8）
  SFTestHTTPServer.*     テスト用のプロセス内 HTTP サーバー
Tools/
  fakebbs.py             手動確認用の偽の掲示板サーバー
  run-app-with-test-home.sh  一時的な HOME でアプリを起動するスクリプト
.github/workflows/       CI（ビルドとテスト）
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

## CI

`.github/workflows/build.yml`（GitHub Actions）が、PR の作成・更新時と main への push 時に次を実行します。

- `macos-26` ランナー（Xcode 26 以降）で `xcodegen generate` → Universal の Release ビルド
- アプリのバイナリに arm64 と x86_64 の両方が含まれていることの確認
- オフラインの回帰テスト（`xcodebuild test`。下の「テスト」を参照）
- ビルドしたアプリ（`SevenFour.zip`）を Artifact として 7 日間保存

ビルド設定を変えるときは、ローカル（Xcode 27）だけでなく CI の Xcode でも通ることを確認してください。

## テスト

`Tests/` に XCTest の単体テスト（ターゲット `SevenFourTests`）があります。ネットワークを使わずに数秒で終わります。

```sh
xcodegen generate
xcodebuild -project SevenFour.xcodeproj -scheme SevenFour -destination 'platform=macOS' -derivedDataPath build test
# 1 クラスだけ: -only-testing:SevenFourTests/Ch2ThreadPostTests
```

- **アプリを起動しないテストです。** テスト対象のコード（`Ch2*.m`、`TEC.m`、互換シム）をテストバンドルに直接コンパイルしています（`project.yml` の `SevenFourTests`）。そのため、`~/Library/Application Support/SevenFour` や設定には触れません。新しいクラスをテストするときは、その `.m` を `project.yml` の `SevenFourTests` の `sources` に追加してください。AppKit の UI（`SF*Controller` など）はこの方式では扱えないので、下の手動確認で見ます。
- テストも MRC です（ARC 無効）。
- **通信のテスト**は、テストプロセス内の HTTP サーバー `SFTestHTTPServer`（127.0.0.1 の空きポート）を使います。実際の URL 読み込み（Cookie、Range、リダイレクト）を通しつつ、応答はテストのブロックで組み立てます。テストの前後で 127.0.0.1 の Cookie を消し、`+[Ch2Thread forgetConfirmationFormData]` で確認ページの hidden 値も忘れさせてください。
- 保存を伴うテスト（DAT のキャッシュ、SQLite）は `SFTestTemporaryDirectory()` の一時ディレクトリを使い、終わったら消します。
- **合成データ**は `Tests/Fixtures/`（UTF-8）にあります。`SFTestFixtureShiftJIS()` で Shift_JIS にして使います。実在の掲示板・利用者のデータは入れないでください。内容は `Tests/Fixtures/README.md` を参照してください。
- 主な対象:
  - `Ch2DatParserTests`: DAT
  - `Ch2BoardTests`: subject.txt、板一覧
  - `Ch2ThreadUpdateTests`: DAT の新規取得・差分取得・416・失敗
  - `Ch2ThreadPostTests`: 書き込み（確認ページの再送、エラー、Shift_JIS）
  - `QuickLiteTests`: SQLite シム

### 手動での確認（スモークテスト）

UI はアプリを動かして確認します。**実際の掲示板には書き込まないでください。** また、普段使っている HOME で試さないでください。

```sh
python3 Tools/fakebbs.py --port 8765          # 偽の掲示板（別のターミナルで）
Tools/run-app-with-test-home.sh               # 一時的な HOME でアプリを起動
```

- `Tools/fakebbs.py`: 板一覧・subject.txt・DAT（Range 対応）と、5ch 風の書き込み確認（確認ページ、Cookie、hidden 値、`?guid=ON`）を返します。本文に `ERRORTEST` を含めるとエラーページを返します。`--delay 4` で応答を遅らせると、更新アイコンの回転を確認できます。
- `Tools/run-app-with-test-home.sh`: `HOME` と `CFFIXED_USER_HOME` を一時ディレクトリにしてアプリを起動します。DB・キャッシュ・Cookie・設定はすべてそこに保存されます。
- 確認する手順:
  1. 起動して、左ペインに板一覧が出る
  2. 「テスト板」を選ぶと、スレッド一覧が出る（読み込み中は「板更新」のアイコンが回る）
  3. スレッドを開く。別のタブでも開き、タブを切り替える
  4. 「書き込む...」で書き込みウインドウを開き、送信する。確認ダイアログが出て、OK で書き込みが完了する。Cancel では本文が残る
- 既知の制限: スレッド一覧から開いたスレッドの URL は、内部でポート番号が落ちます（`SFThreadFactory` / `SFURLProtocol`）。そのため、ローカルの偽サーバーではスレッドの本文を取得できません。`Ch2Thread` 自体はポートを保ちます。

## コーディング上の注意

- **MRC のまま維持すること。** `retain` / `release` / `autorelease` / `dealloc` のバランスに注意してください。ARC は有効にしないでください（`CLANG_ENABLE_OBJC_ARC: NO`）。
- 外部フレームワーク（OgreKit、QuickLite）は使えません。`#import <OgreKit/OgreKit.h>` や `#import <QuickLite/...>` は `SevenFour/Compat/` のシムが解決します（`HEADER_SEARCH_PATHS`）。
  - OgreKit シム: Ruby 構文の OgreKit と同様に `^` / `$` は行単位でマッチし、置換文字列の `\0`〜`\9` はキャプチャグループを表します。
  - QuickLite シム: 列には `"subject"` と `"threads.subject"` のどちらの名前でもアクセスできます。`QuickLiteCursor -save` は ROWID を使って `UPDATE` します（単一テーブルの `SELECT` で取得したカーソルのみ対応）。値はバインドされるので、`setValue:forColumn:` に渡す文字列を `prepareStringForQuery:` でエスケープしないでください。
  - 新しい API が必要な場合は、シムに実装を足すか、標準 API（`NSRegularExpression`、`sqlite3`）を直接使ってください。
- 現行 SDK で削除された API（`NSMenuView`、`-[NSFont defaultLineHeightForFont]` など）は代替 API に置き換えてください。非推奨（deprecated）なだけの API はそのまま使えます。
- `.nib` は旧形式のバイナリなので、テキストとして編集できません。UI を変えるときは、コードで変更するか `.xib` への移行を検討してください。
  - 旧 nib には現行 AppKit で読み込むと例外になるデータが残っていることがあります（例: `PostWindow.nib` の `NSComboBox` 内部テーブル列の `NSIdentifier` が数値だった。#2）。`keyedobjects.nib` は NSKeyedArchiver のバイナリ plist なので、`plistlib` などで該当オブジェクトだけを書き換えて修正できます。
  - `.nib` ディレクトリ内のファイルだけを変更しても Xcode は再コンパイルしません。`touch SevenFour/Japanese.lproj/<Name>.nib` してからビルドしてください。
- IBAction やツールバーのアクション内で発生した Objective-C 例外は AppKit に握りつぶされ、ログにも出ません。「ボタンを押しても何も起きない」場合は、例外を疑って `@try`/`@catch` で一時的にログを出すか、lldb で `objc_exception_throw` にブレークポイントを置いて調べてください。
- **スレッドとメインスレッド**（#9）: `SFThread` / `Ch2Thread` の更新・通知と WebView の操作はメインスレッドで行います。`SFURLProtocol` は CFNetwork のスレッドで動くので、スレの更新と HTML 生成はメインスレッドで行い、結果だけを読み込みを始めたスレッドで client に渡しています。旧 WebView（WebKitLegacy）をメインスレッド以外から触ると例外で終了します。
- **書き込み（`Ch2Thread -postWithName:mail:body:`）の注意**（#7）
  - Cookie は自前で `Cookie` ヘッダを組み立てず、共有の `NSHTTPCookieStorage` に任せます。bbs.cgi が書き込み確認ページで発行した Cookie を次の書き込みで送り返す必要があるためです。
  - 確認ページで OK を押したとき（同じ名前・メール・本文での再送）は、確認ページの `<form>`（`action`、hidden の値、送信ボタンの name/value）をブラウザと同じようにそのまま送ります（#12）。値は Shift_JIS で URL エンコードします。
  - それ以外の書き込みでは、`time` に現在の UNIX 時刻を送り、以前の確認ページの hidden の値（`sharedFormData_`）も付けます。
  - 実際の掲示板で書き込みに失敗する場合は、`defaults write com.xrea.s74.quux.SevenFour DebugPostResponse -bool YES` を設定すると、最後の応答が `~/Library/Logs/SevenFour/LastPostResponse.html` に保存されます（書き込んだ本文も含まれます）。
  - 実際の掲示板に書き込んで試さないでください。ローカルの偽サーバー（確認ページ・Cookie・hidden 値を再現したもの）で確認します。
- **アイコンは SF Symbols を使います**（#5）。画像ファイルは追加しないでください。
  - ツールバー: `Japanese.lproj/Toolbar.plist` の各項目の `symbol` キーにシンボル名を書きます（`SFMainWindowController.m` が `+[NSImage imageWithSystemSymbolName:accessibilityDescription:]` で読み込みます）。
  - 処理中にアニメーションさせる項目（板更新・スレ更新）は、`Toolbar.plist` で `animates` を `true` にします（#15）。その項目は `SFSymbolToolbarItem`（`NSImageView` を持つボタン）で作られ、`-isToolbarItemBusy:` が YES の間、シンボルを回転させます。シンボルエフェクトには `Symbols.framework` が必要です（`project.yml` でリンク済み）。
  - 処理が終わったら `-validateToolbarSoon:` を呼んでツールバーを再検証すると、アニメーションが止まります。
  - セルやボタンに色付きで描くときは `NSImage+SFSymbols.h` の `+sf_imageWithSymbolName:pointSize:color:size:` を使います（テンプレート画像にならないので色がそのまま出ます。動的カラーはダークモードに追従します）。
  - 例外: タブの背景（`tab.png`）、アプリアイコン（`74.icns`）、分割バーの模様（`HTThreePaneSplitView.m`）はアイコンではないので画像のままです。
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

- 起動するとメインウィンドウ（左ペインの板一覧・スレッド一覧・タブ付き WebView）が表示されれば OK です。
- 変更後は少なくとも、Universal ビルドとテスト（「テスト」を参照）が通ること、arm64 で起動することを確認してください。
- Intel 版は Intel Mac、または Rosetta 2 が入った Apple silicon Mac で `arch -x86_64 .../SevenFour` を実行して確認します。
