# SevenFourRetro

SevenFour は、2005〜2006 年ごろに書かれた Mac OS X 用の 2ch ブラウザです（Cocoa / Objective-C）。
このリポジトリでは、それを **macOS 26 以降の Apple silicon (arm64) と Intel (x86_64)** で動くように保守しています。

- 元の配布サイト: https://quux.s74.xrea.com/ （最終版は SevenFour 1.3、Panther 以降対応のユニバーサルバイナリ）
- リポジトリ名の「Retro」は、Swift への移植版（[mtakagi/SevenFour](https://github.com/mtakagi/SevenFour)）のプロジェクト名に「Modern」が付いているのと対にしたものです。こちらは元の Objective-C のコードを、できるだけ元の作りのまま動かし続けるためのものです。

## できること

元の SevenFour の機能を、現行の macOS で使えるようにしています。

- 3 ペイン（板一覧・スレッド一覧・本文）のウインドウと、本文のタブ
- レスや ID のポップアップ、画像のポップアップ
- 書き込み（確認ページ、Cookie を含む）
- HTML / CSS / JavaScript でカスタマイズできるスキン
- ログは `.dat` で保存（索引は SQLite）

元のサイトの「ない」リスト（お気に入り、スレ立て、迷惑レスフィルタ、Be、● など）にあるものは、ここでもありません。

### 元の版からのおもな変更

- XcodeGen でビルドする Universal (arm64 + x86_64) のアプリ。デプロイメントターゲットは macOS 26
- 通信は `NSURLSession` による非同期の HTTPS（App Transport Security の例外なし）。板一覧の既定は `https://menu.5ch.io/bbsmenu.html`
- 本文とポップアップは `WKWebView`（旧 WebView は使っていません）
- メインウインドウ・書き込みウインドウ・ポップアップは AppKit のコードで作成（ドロワーはなくし、板一覧は常に左ペイン）
- OgreKit と QuickLite は、`NSRegularExpression` と `libsqlite3` を使う互換シム（`SevenFour/Compat/`）に置き換え
- Shift_JIS は Windows と同じ CP932 として読み込み
- アイコンは SF Symbols

## ビルド

Xcode（macOS 26 SDK 以降）と [XcodeGen](https://github.com/yonaskolb/XcodeGen) が必要です。Xcode プロジェクトは `project.yml` から生成するので、リポジトリには含めていません。

```sh
brew install xcodegen
xcodegen generate

# Universal (arm64 + x86_64) の Release ビルド
xcodebuild -project SevenFour.xcodeproj -scheme SevenFour \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath build build

open build/Build/Products/Release/SevenFour.app
```

アプリはアドホック署名です。

## テスト

```sh
xcodebuild -project SevenFour.xcodeproj -scheme SevenFour -destination 'platform=macOS' -derivedDataPath build test
```

ネットワークを使わない単体テスト（DAT・subject.txt・差分取得・書き込み・SQLite・Shift_JIS など）です。
UI は、偽の掲示板サーバー（`Tools/fakebbs.py`）と、一時的な HOME でアプリを起動するスクリプト（`Tools/run-app-with-test-home.sh`）を使って確かめます。実際の掲示板に書き込んで試さないでください。

開発の詳しい手順と注意（MRC、警告ゼロ、nib の扱い、通信や書き込みの決まりごとなど）は [AGENTS.md](AGENTS.md) にあります。`docs/` には、読み進め操作の記録や WKWebView への移行の記録があります。

## ライセンス

SevenFour 本体は、作者が著作権を放棄しています。このリポジトリでの変更も同じ扱いです。
ただし、作者が別の部品にはそれぞれの条件があります。詳しくは [LICENSE.md](LICENSE.md) を見てください。

## 謝辞

元の SevenFour の作者に感謝します。
3 ペインまわりのコード（`HTThreePaneSplitView`）はヘチマ氏、スキンの一部は Prototype JavaScript Framework、アイコンはゴルァのひとと SevenFour スレの名無しのみなさんによるものです（元のサイトの謝辞より）。
