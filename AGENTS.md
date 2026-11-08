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

- **アプリを起動しないテストです。** テスト対象のコード（`Ch2*.m`、互換シム）をテストバンドルに直接コンパイルしています（`project.yml` の `SevenFourTests`）。そのため、`~/Library/Application Support/SevenFour` や設定には触れません。新しいクラスをテストするときは、その `.m` を `project.yml` の `SevenFourTests` の `sources` に追加してください。AppKit の UI（`SF*Controller` など）はこの方式では扱えないので、下の手動確認で見ます。
- テストも MRC です（ARC 無効）。
- **通信のテスト**は、テストプロセス内の HTTP サーバー `SFTestHTTPServer`（127.0.0.1 の空きポート）を使います。実際の URL 読み込み（Cookie、Range、リダイレクト）を通しつつ、応答はテストのブロックで組み立てます。テストの前後で 127.0.0.1 の Cookie を消し、`+[Ch2Thread forgetConfirmationFormData]` で確認ページの hidden 値も忘れさせてください。
- 保存を伴うテスト（DAT のキャッシュ、SQLite）は `SFTestTemporaryDirectory()` の一時ディレクトリを使い、終わったら消します。
- **合成データ**は `Tests/Fixtures/`（UTF-8）にあります。`SFTestFixtureShiftJIS()` で Shift_JIS にして使います。実在の掲示板・利用者のデータは入れないでください。内容は `Tests/Fixtures/README.md` を参照してください。
- 主な対象:
  - `Ch2DatParserTests`: DAT
  - `Ch2BoardTests`: subject.txt、板一覧（非同期の取得、失敗、取り消し）
  - `Ch2ThreadUpdateTests`: DAT の新規取得・差分取得・416・失敗・途中で切れた応答・Range を無視した 200・取り消し
  - `Ch2ThreadPostTests`: 書き込み（確認ページの再送、エラー、Shift_JIS）
  - `QuickLiteTests`: SQLite シム
  - `Ch2ShiftJISTests`: Shift_JIS（CP932）の読み込み（拡張文字、壊れたバイト、途中で切れたデータ）

### 手動での確認（スモークテスト）

UI はアプリを動かして確認します。**実際の掲示板には書き込まないでください。** また、普段使っている HOME で試さないでください。

```sh
python3 Tools/fakebbs.py --port 8765          # 偽の掲示板（別のターミナルで）
Tools/run-app-with-test-home.sh               # 一時的な HOME でアプリを起動
```

- `Tools/fakebbs.py`: 板一覧・subject.txt・DAT（Range 対応）と、5ch 風の書き込み確認（確認ページ、Cookie、hidden 値、`?guid=ON`）を返します。本文に `ERRORTEST` を含めるとエラーページを返し、`LOSTTEST` を含めると書き込みを受け付けたうえで応答を途中で切ります（結果が分からない場合の確認用）。`--delay 4` で GET の応答を遅らせると更新アイコンの回転を、`--post-delay 3` で書き込みの応答を遅らせると送信中の書き込みウインドウを確認できます。
- `Tools/run-app-with-test-home.sh`: `HOME` と `CFFIXED_USER_HOME` を一時ディレクトリにしてアプリを起動します。DB・キャッシュ・Cookie・設定はすべてそこに保存されます。
- 確認する手順:
  1. 起動して、左ペインに板一覧が出る
  2. 「テスト板」を選ぶと、スレッド一覧が出る（読み込み中は「板更新」のアイコンが回る）
  3. スレッドを開く。別のタブでも開き、タブを切り替える
  4. 「書き込む...」で書き込みウインドウを開き、送信する。確認ダイアログが出て、OK で書き込みが完了する。Cancel では本文が残る
  5. `--post-delay 3` で、送信中も本文を編集できること、「書き込む」ボタンが押せないこと、送信中にウインドウを閉じても落ちないことを確認する。本文に `LOSTTEST` を含めると「書き込めたかどうか分かりません。」が出て、再送のボタンがないことを確認する

## コーディング上の注意

- **MRC のまま維持すること。** `retain` / `release` / `autorelease` / `dealloc` のバランスに注意してください。ARC は有効にしないでください（`CLANG_ENABLE_OBJC_ARC: NO`）。
- 外部フレームワーク（OgreKit、QuickLite）は使えません。`#import <OgreKit/OgreKit.h>` や `#import <QuickLite/...>` は `SevenFour/Compat/` のシムが解決します（`HEADER_SEARCH_PATHS`）。
  - OgreKit シム: Ruby 構文の OgreKit と同様に `^` / `$` は行単位でマッチし、置換文字列の `\0`〜`\9` はキャプチャグループを表します。
  - QuickLite シム: 列には `"subject"` と `"threads.subject"` のどちらの名前でもアクセスできます。`QuickLiteCursor -save` は ROWID を使って `UPDATE` します（単一テーブルの `SELECT` で取得したカーソルのみ対応）。値はバインドされるので、`setValue:forColumn:` に渡す文字列を `prepareStringForQuery:` でエスケープしないでください。
  - 新しい API が必要な場合は、シムに実装を足すか、標準 API（`NSRegularExpression`、`sqlite3`）を直接使ってください。
- 現行 SDK で削除された API（`NSMenuView`、`-[NSFont defaultLineHeightForFont]` など）は代替 API に置き換えてください。
- **コンパイラの警告はゼロに保ちます**（#32）。非推奨 API の警告（`GCC_WARN_ABOUT_DEPRECATED_FUNCTIONS`）と、`objc_msgSend` の型チェック（`ENABLE_STRICT_OBJC_MSGSEND`）は有効です。新しく警告を出さないでください。
  - 旧 WebView（WebKit 1）の非推奨警告だけは、`project.yml` の `DISABLE_LEGACY_WEBKIT_DEPRECATIONS` で止めています。WKWebView への移行（#27、#28）で WebKit 1 をなくしたら、この定義を削除してください。
  - それ以外で、すぐに置き換えられない非推奨 API は、使う箇所だけを `#pragma clang diagnostic push` / `ignored "-Wdeprecated-declarations"` / `pop` で囲み、理由と担当の Issue をコメントに書いてください。現在は MainWindow の `NSDrawer`、SidePane の `+[NSBundle loadNibNamed:owner:]`、ツールバー項目の `setMinSize:` / `setMaxSize:` だけです（#29）。
  - `objc_msgSend` を直接呼ぶときは、メソッドの型にキャストしてから呼んでください（`Compat/OgreKit/OgreKit.m` を参照）。
  - デリゲートやデータソースにするクラスは、プロトコル（`NSWindowDelegate`、`WebPolicyDelegate` など）を宣言してください。宣言しないと型の警告が出て、メソッドの型の食い違いも見つかりません。
  - ローカルで `ld: warning: search path '...' not found` が出る場合は、シェルの `LIBRARY_PATH` などの環境によるもので、プロジェクトの警告ではありません。
- `.nib` は旧形式のバイナリなので、テキストとして編集できません。UI を変えるときは、コードで変更するか `.xib` への移行を検討してください。
  - 旧 nib には現行 AppKit で読み込むと例外になるデータが残っていることがあります（例: `PostWindow.nib` の `NSComboBox` 内部テーブル列の `NSIdentifier` が数値だった。#2）。`keyedobjects.nib` は NSKeyedArchiver のバイナリ plist なので、`plistlib` などで該当オブジェクトだけを書き換えて修正できます。
  - `.nib` ディレクトリ内のファイルだけを変更しても Xcode は再コンパイルしません。`touch SevenFour/Japanese.lproj/<Name>.nib` してからビルドしてください。
- IBAction やツールバーのアクション内で発生した Objective-C 例外は AppKit に握りつぶされ、ログにも出ません。「ボタンを押しても何も起きない」場合は、例外を疑って `@try`/`@catch` で一時的にログを出すか、lldb で `objc_exception_throw` にブレークポイントを置いて調べてください。
- **スレッドとメインスレッド**（#9）: `SFThread` / `Ch2Thread` の更新・通知と WebView の操作はメインスレッドで行います。`SFURLProtocol` は CFNetwork のスレッドで動くので、スレの更新と HTML 生成はメインスレッドで行い、結果だけを読み込みを始めたスレッドで client に渡しています。旧 WebView（WebKitLegacy）をメインスレッド以外から触ると例外で終了します。
- **通信（NSURLSession）**（#24、#25、#26）: 板一覧（`Ch2BoardTree`）・スレッド一覧（`Ch2Board`）・画像（`SFImageWindowController`）・DAT（`Ch2Thread -update`）・書き込み（`Ch2Thread -postWithName:mail:body:completionHandler:`）は、すべて `NSURLSession` で非同期に通信します。`NSURLConnection` と同期通信は使わないでください。
  - 結果はメインスレッドで扱います（デリゲートのキューに `[NSOperationQueue mainQueue]` を指定するか、完了ハンドラから `dispatch_async(dispatch_get_main_queue(), ...)`）。
  - 取り消したあとに届いた応答は捨てます（`-cancel`、セッションやタスクが今のものか確認する）。板を離れたとき（`SFNormalBoard` の解放）や画像ウインドウを閉じたときは取り消します。
  - デリゲート付きの `NSURLSession` はデリゲートを retain します。終わったら `finishTasksAndInvalidate`、取り消すときは `invalidateAndCancel` を呼んでください。呼ばないとリークします。
  - 板一覧の取得に失敗したとき（接続できない、HTTP エラー、板が 1 つもないページ）は、保存済みの `BoardTree.plist` を上書きしません。初回起動ではスマート板だけを先に表示し、届いたら左ペインを更新します（`SFBoardTreeDidChangeNotification`）。
  - DAT の差分取得では、キャッシュを壊さないように次のようにしています（`Ch2ThreadUpdateTests`）。
    - 206 は、`Content-Range` の開始位置がキャッシュの長さと一致するときだけ追記します。`Content-Range` がない・読めない 206 も追記しません。
    - Range を付けたのに 200（DAT 全体）が返ったら、追記せずにキャッシュを置き換えます。
    - 応答の最後が改行で終わっていなければ、最後の行は捨てます（次の Range でその行から取り直す）。
    - 接続が途中で切れた、416、HTTP エラーのときは、キャッシュを変えません。
    - 更新中の `-update` は無視します（同じスレを複数のタブで開いている場合）。ログを削除したときは、更新中の応答でキャッシュを書き戻しません（`SFThread`）。
- **書き込み（`Ch2Thread -postWithName:mail:body:completionHandler:`）の注意**（#7、#26）
  - 非同期で送り、結果は完了ハンドラ（メインスレッド）で受け取ります。送信中の書き込みは拒否され（戻り値 NO）、二重に送られません。`SFThread` は書き込み専用の `Ch2Thread`（`poster_`）を使います。DAT 用の `thread_` はログを削除すると作り直されますが、`poster_` は作り直さないので、送信中の書き込み・応答のメッセージ・確認ページのフォームが失われません。`SFPostWindowController` は送信中「書き込む」ボタンを無効にし、送信中に内容を変えた場合は、成功してもウインドウを閉じません。
  - POST は自動で再送しません。送ったあとに応答が途中で切れた・タイムアウトした場合は `Ch2ThreadPostUnknown`（書き込めたか分からない）になり、ウインドウは再送のボタンを出さずにスレッドを更新します。接続できなかった場合（送っていない）は `Ch2ThreadPostClientError` です。
  - 書き込みごとに新しい `NSURLSession` を使います（使い回した接続で失敗した POST を CFNetwork が送り直さないように）。Cookie は共有のストレージを使います。
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
- **Shift_JIS の読み込み**（#31）: 掲示板から受け取ったデータ（板一覧・subject.txt・DAT・bbs.cgi の応答）は `Ch2StringFromShiftJIS()`（`Ch2ShiftJIS.h`）で文字列にしてください。Windows と同じ CP932 として読み、壊れたバイトは U+FFFD に、末尾で切れた文字は捨てます。`-[NSString initWithData:encoding:]` は 1 バイトでも壊れていると全体が nil になるので使わないでください。旧 Text Encoding Converter（`TEC.m`）は削除しました。
- ソースのエンコーディングは UTF-8 です。
- **通信は HTTPS 前提です。** 現行 SDK では App Transport Security (ATS) が有効なため、平文 HTTP の通信はブロックされます。ATS の例外は設定していません。
  - 板一覧のデフォルトは `https://menu.5ch.io/bbsmenu.html` です（`SFAppController.m`）。
  - 板・スレッド・DAT の URL を組み立てるときは `http://` を直接書かず、プレフィックスヘッダの `SFSchemeOfURL()`（http と明示されていなければ https）と `SFIsWebURL()` を使ってください。
  - スレッドの URL（`read.cgi` / `dat`）から板とスレッド番号を取り出すときは `+[Ch2Thread boardOfThreadURL:number:]` を、スレッドの URL を作るときは `+URLOfHTMLWithBoard:number:` / `+URLOfDatWithBoard:number:` を使ってください。どれもポートを保ちます（#37）。ホストだけで URL を組み立て直さないでください。
  - 内部 URL `sevenfour://host[:port]/...` はスキームを持ちません。`SFThreadFactory -threadWithURL:` は、すでに開いているスレッド（https、次に http）を探し、なければ https として扱います。
  - HTTP でしか提供されていない画像（スレッド内のリンク）や板は、ATS により読み込めません。

## 動作確認

```sh
open build/Build/Products/Release/SevenFour.app
```

- 起動するとメインウィンドウ（左ペインの板一覧・スレッド一覧・タブ付き WebView）が表示されれば OK です。
- 変更後は少なくとも、Universal ビルドとテスト（「テスト」を参照）が通ること、arm64 で起動することを確認してください。
- Intel 版は Intel Mac、または Rosetta 2 が入った Apple silicon Mac で `arch -x86_64 .../SevenFour` を実行して確認します。
