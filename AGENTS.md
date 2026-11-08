# AGENTS.md

このファイルはこのリポジトリで作業する AI エージェント（Claude Code、Codex など）と開発者向けのガイドです。
`CLAUDE.md` はこのファイルへのシンボリックリンクなので、編集するのは `AGENTS.md` だけにしてください。

## プロジェクト概要

SevenFour は 2005〜2006 年頃に書かれた macOS 用 2ch ブラウザ（Cocoa / Objective-C）です。
このリポジトリでは、それを **macOS 26 以降の Apple silicon (arm64) と Intel (x86_64)** で動かせるように保守しています。

- 言語: Objective-C（**手動参照カウント / MRC**。ARC は無効）
- UI: メインウインドウ（#29）・書き込みウインドウ（#30）・レスのポップアップウインドウ（#28）はコードで作っています。メニュー・環境設定（`MainMenu.nib`）と画像ウインドウ（`ImageWindow.nib`）は旧形式の Interface Builder `.nib`（`SevenFour/Japanese.lproj/*.nib`、keyedobjects 形式）のままです
- 表示: `WKWebView`（#28）+ `SevenFour/Skin/` の HTML/CSS/JS
- 保存: SQLite（`~/Library/Application Support/SevenFour/Index.db`）

## ディレクトリ構成

```
README.md                利用者向けの説明（#33）
LICENSE.md               ライセンス（SevenFour 本体は著作権放棄。作者が別の部品の条件も記載）
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
docs/                    記録・設計の文書（retro-reading-flow.md は読み進め操作の記録（#22）、wkwebview-migration.md は WKWebView への移行で置き換えた機能（#27、#28））
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

- `Tools/fakebbs.py`: 板一覧・subject.txt・DAT（Range 対応）と、5ch 風の書き込み確認（確認ページ、Cookie、hidden 値、`?guid=ON`）を返します。板は「テスト板」（2 スレ）のほか、たくさんのスレを読み進める確認用の「読み進め板」（40 スレ、300 レスのスレを含む）と「雑談板」（30 スレ）があります（`docs/retro-reading-flow.md`）。受け付けた書き込みはそのスレの最後に追加されるので、新着の確認にも使えます（メモリ上だけで、起動し直すと元に戻ります）。本文に `ERRORTEST` を含めるとエラーページを返し、`LOSTTEST` を含めると書き込みを受け付けたうえで応答を途中で切ります（結果が分からない場合の確認用）。`--delay 4` で GET の応答を遅らせると更新アイコンの回転を、`--post-delay 3` で書き込みの応答を遅らせると送信中の書き込みウインドウを確認できます。
- `Tools/run-app-with-test-home.sh`: `HOME` と `CFFIXED_USER_HOME` を一時ディレクトリにしてアプリを起動します。DB・キャッシュ・Cookie はそこに保存されます。
  - **設定（NSUserDefaults）は HOME を変えても分けられません**（cfprefsd が本当のホームの `~/Library/Preferences` に保存します）。そのため、スクリプトはアプリをコピーしてバンドル ID を `com.xrea.s74.quux.SevenFour.test` に変えて起動し、終了時にその設定を削除します。普段の設定（`com.xrea.s74.quux.SevenFour`）には触れません。
  - アプリを操作するときは、このバンドル ID を使ってください（例: `osascript -e 'tell application id "com.xrea.s74.quux.SevenFour.test" to activate'`）。
  - アプリを直接起動して試さないでください（普段の設定に書き込まれます）。
- 確認する手順:
  1. 起動して、左ペインに板一覧が出る
  2. 「テスト板」を選ぶと、スレッド一覧が出る（読み込み中は「板更新」のアイコンが回る）
  3. スレッドを開く。別のタブでも開き、タブを切り替える
  4. 「書き込む...」で書き込みウインドウを開き、送信する。確認ダイアログが出て、OK で書き込みが完了する。Cancel では本文が残る
  5. `--post-delay 3` で、送信中も本文を編集できること、「書き込む」ボタンが押せないこと、送信中にウインドウを閉じても落ちないことを確認する。本文に `LOSTTEST` を含めると「書き込めたかどうか分かりません。」が出て、再送のボタンがないことと、スレが更新されて書き込んだレスが表示されることを確認する（偽サーバーは書き込みを受け付けてから応答を切ります）

## コーディング上の注意

- **MRC のまま維持すること。** `retain` / `release` / `autorelease` / `dealloc` のバランスに注意してください。ARC は有効にしないでください（`CLANG_ENABLE_OBJC_ARC: NO`）。
- 外部フレームワーク（OgreKit、QuickLite）は使えません。`#import <OgreKit/OgreKit.h>` や `#import <QuickLite/...>` は `SevenFour/Compat/` のシムが解決します（`HEADER_SEARCH_PATHS`）。
  - OgreKit シム: Ruby 構文の OgreKit と同様に `^` / `$` は行単位でマッチし、置換文字列の `\0`〜`\9` はキャプチャグループを表します。
  - QuickLite シム: 列には `"subject"` と `"threads.subject"` のどちらの名前でもアクセスできます。`QuickLiteCursor -save` は ROWID を使って `UPDATE` します（単一テーブルの `SELECT` で取得したカーソルのみ対応）。値はバインドされるので、`setValue:forColumn:` に渡す文字列を `prepareStringForQuery:` でエスケープしないでください。
  - 新しい API が必要な場合は、シムに実装を足すか、標準 API（`NSRegularExpression`、`sqlite3`）を直接使ってください。
- 現行 SDK で削除された API（`NSMenuView`、`-[NSFont defaultLineHeightForFont]` など）は代替 API に置き換えてください。
- **コンパイラの警告はゼロに保ちます**（#32）。非推奨 API の警告（`GCC_WARN_ABOUT_DEPRECATED_FUNCTIONS`）と、`objc_msgSend` の型チェック（`ENABLE_STRICT_OBJC_MSGSEND`）は有効です。新しく警告を出さないでください。
  - 旧 WebView（WebKit 1）は #28 でなくしました。使わないでください（`WKWebView` を使います）。
  - すぐに置き換えられない非推奨 API は、使う箇所だけを `#pragma clang diagnostic push` / `ignored "-Wdeprecated-declarations"` / `pop` で囲み、理由と担当の Issue をコメントに書いてください。現在はありません（MainWindow の `NSDrawer` などは #29 でなくしました）。
  - `objc_msgSend` を直接呼ぶときは、メソッドの型にキャストしてから呼んでください（`Compat/OgreKit/OgreKit.m` を参照）。
  - デリゲートやデータソースにするクラスは、プロトコル（`NSWindowDelegate`、`WKNavigationDelegate` など）を宣言してください。宣言しないと型の警告が出て、メソッドの型の食い違いも見つかりません。
  - ローカルで `ld: warning: search path '...' not found` が出る場合は、シェルの `LIBRARY_PATH` などの環境によるもので、プロジェクトの警告ではありません。
- `.nib` は旧形式のバイナリなので、テキストとして編集できません。UI を変えるときは、コードで変更するか `.xib` への移行を検討してください。
  - 書き込みウインドウ（`SFPostWindowController -makeWindow`）は、`PostWindow.nib` と同じ配置・リサイズの挙動をコードで作っています（#30）。メインウインドウ（`SFMainWindowController+Window.m`、`SFSidePaneController -makeView`）も同じです（#29）。ほかの nib をコードに移すときの参考にしてください。
  - メインウインドウ（#29）: 板一覧は常に左ペイン（3 ペインの分割ビュー `SFThreePaneView` の side view）です。ドロワー（`NSDrawer`）はなくしたので、旧設定の `UseDrawer`・`DrawerEdge`・`DrawerSize` は読みません。環境設定（`MainMenu.nib`）のドロワーの項目は、nib のビューに非表示のビット（`NSvFlags` の 0x80000000）を立てて隠しています。Tab キーの順は、ウインドウが画面上の位置から決めます（`autorecalculatesKeyViewLoop`）。
  - 3 ペインの分割ビュー（#57）: `SFThreePaneView` は `NSSplitView` を 2 つ入れ子にしたものです（外側が板一覧｜それ以外、内側がスレッド一覧／本文タブ）。分割位置は `NSSplitView` の自動保存（`SplitView Side` / `SplitView Main`）で保存します。以前の `HTThreePaneSplitView`（ヘチマ氏作。再配布の条件が明記されていないため置き換えた）が保存した位置（`HTThreePaneSplitView_SplitView`）は、新しい保存がないときに一度だけ引き継ぎます。板一覧と本文の表示切り替えはビューを隠して行います（隠したあとは分割ビューのレイアウトをやり直さないと、分割線が残って見えます）。テーブルとアウトラインの `style` は `NSTableViewStyleFullWidth` にしています（自動のままだと、分割ビューの左端のペインで角の丸い行になります）。
  - nib の設定を正確に知るには、ビルドしたアプリの nib を小さなプログラムで読み込み（`NSNib` の `-initWithNibData:bundle:`、持ち主は `setValue:forUndefinedKey:` を受け流すオブジェクト）、できたビューやテーブル列の値（大きさ、autoresizing mask、列の幅・並べ替え・バインディングなど）を表示する方法もあります（#29 で使いました）。nib の配置や設定は、`keyedobjects.nib` を `plistlib` で読むと分かります（`NSFrame`、`NSvFlags` の下位 6 ビットが autoresizing mask）。
  - 旧 nib には現行 AppKit で読み込むと例外になるデータが残っていることがあります（例: 旧 `PostWindow.nib` の `NSComboBox` 内部テーブル列の `NSIdentifier` が数値だった。#2。この nib は #30 でコードに置き換えました）。`keyedobjects.nib` は NSKeyedArchiver のバイナリ plist なので、`plistlib` などで該当オブジェクトだけを書き換えて修正できます。
  - `.nib` ディレクトリ内のファイルだけを変更しても Xcode は再コンパイルしません。`touch SevenFour/Japanese.lproj/<Name>.nib` してからビルドしてください。
- IBAction やツールバーのアクション内で発生した Objective-C 例外は AppKit に握りつぶされ、ログにも出ません。「ボタンを押しても何も起きない」場合は、例外を疑って `@try`/`@catch` で一時的にログを出すか、lldb で `objc_exception_throw` にブレークポイントを置いて調べてください。
- **タブと本文の境界**（#27）: タブバー（`TabbedWebView`）は WebKit を使いません。タブの中身は `NSView<SFTabContent>`（`SFTabContent.h`）で、名前（`-tabTitle`）と読み込み中かどうか（`-isTabLoading`）だけを受け取り、変化は `SFTabContentDidChangeNotification` で知ります。
  - 本文（`SFThreadView`）がこれを実装します（#28）。
- **ページの表示（WKWebView）**（#28）: 本文（`SFThreadView`）とレスのポップアップウインドウ（`SFPopUpWindowController`）は、どちらも `SFPageView`（`WKWebView` のサブクラス）で表示します。
  - `sevenfour://`（スレとスキン）は `SFThreadSchemeHandler`（`WKURLSchemeHandler`）が返します。スキンのファイルの場所は `+[SFThreadHTMLFormatter pathOfSkinFile:]` で決めます（利用者のスキン、なければアプリ内）。
  - リンクとマウスを乗せたリンクは、`SFPageView` のデリゲート（`-setPageDelegate:`、`SFPageViewDelegate`）で `SFMainWindowController` に伝えます。マウスを乗せたことは、`WKWebView` に API がないので、ユーザースクリプトから `WKScriptMessageHandler` で受け取ります。
  - ポップアップの高さは、ページの高さをユーザースクリプトから受け取って合わせます（`SFPageViewContentHeightDidChangeNotification`）。
  - 本文の URL やページ内検索も、`SFThreadView` のメソッド（`-pageURL`、`-findString:forward:`）を通します。`SFMainWindowController` からは `-selectedThreadView` で選択中の本文を取ります。
  - WKWebView への移行で置き換えた機能と確認の手順は `docs/wkwebview-migration.md` にあります。
  - 本文の WebView のレスポンダーチェーンは差し替えないでください（#44。最初のページがスクロールしなくなります）。
  - **キーボードフォーカス**（#46）: スレを開く（読み込みが終わる）と、前面のタブの本文がファーストレスポンダーになり、`SFThreadView` がフォーカスリングを描きます（`WKWebView` は描かないため）。背面に開くときはフォーカスを動かしません。タブバー（`TabbedWebView`）はファーストレスポンダーにならないでください（Tab キーの途中に見えない場所ができます）。スレッド一覧で編集できる列は評価（`rate`）だけです（ほかの列が編集できると、Tab キーでセルの編集が始まります）。
- **スレッドとメインスレッド**（#9）: `SFThread` / `Ch2Thread` の更新・通知と WebView の操作はメインスレッドで行います。`SFThreadSchemeHandler` はメインスレッドで動きます。
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
  - 例外: タブの背景（`tab.png`）はアイコンではないので画像のままです。アプリのアイコンは Icon Composer の `SevenFour/74.icon` で、`project.yml` の `ASSETCATALOG_COMPILER_APPICON_NAME` で指定しています（#58。数字は Noto Sans をアウトライン化したもの）。
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

- 起動するとメインウィンドウ（左ペインの板一覧・スレッド一覧・タブ付きの本文）が表示されれば OK です。
- 変更後は少なくとも、Universal ビルドとテスト（「テスト」を参照）が通ること、arm64 で起動することを確認してください。
- Intel 版は Intel Mac、または Rosetta 2 が入った Apple silicon Mac で `arch -x86_64 .../SevenFour` を実行して確認します。
