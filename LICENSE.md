# ライセンス

## SevenFour 本体

元の作者は、SevenFour 本体の著作権を放棄しています。配布サイト（https://quux.s74.xrea.com/ ）の表記は次のとおりです。

> SevenFour本体については、著作権がらみはいっさい放棄します。すきに使ってください。

> This software is not copyrighted and may be used freely.

ソースファイルの先頭にも、同じ趣旨の `This file is not copyrighted and may be used freely.` が書かれています。

## このリポジトリでの変更

このリポジトリ（SevenFourRetro）で加えた変更・追加（ビルド設定、互換シム、テスト、ツール、文書を含む）も、元の SevenFour 本体と同じく著作権を放棄します。すきに使ってください。

This repository's changes and additions are likewise not copyrighted and may be used freely.

## 作者が別の部品

次の部品は SevenFour 本体に含まれず、それぞれの作者の条件に従います。

| 部品 | 場所 | 作者・条件 |
| --- | --- | --- |
| HTThreePaneSplitView | `SevenFour/HTThreePaneSplitView.h` / `.m` | ヘチマ（hetima）氏。ソースには `Copyright 2005 hetima. All rights reserved.` とあります。元のサイトの謝辞によると、SevenFour のために書いてもらったコードです。再配布の条件は明記されていないので、書き直した実装に置き換えます（#57）。 |
| Prototype JavaScript Framework 1.4.0 | `SevenFour/Skin/prototype.js` | (c) 2005 Sam Stephenson。MIT 形式のライセンス（ファイルの先頭と、アプリの Credits を参照）。 |
| アプリのアイコン | `SevenFour/74.icns` | ゴルァのひとと、SevenFour スレの名無しのみなさん（元のサイトの謝辞より）。条件は明記されていないので、新しいアイコンに変えます（#58）。 |

元の SevenFour は QuickLite（Tito Ciuro、BSD 形式）・OgreKit（Isao Sonobe、BSD 形式）・鬼車（K.Kosako、BSD 形式）・SQLite（パブリックドメイン）を使っていました。このリポジトリには QuickLite・OgreKit・鬼車のコードは含まれていません。代わりに、同じ API を `libsqlite3` と `NSRegularExpression` で実装した互換シム（`SevenFour/Compat/`、このリポジトリで新しく書いたもの）を使っています。SQLite は macOS のものを使います。アプリの Credits（`SevenFour/English.lproj/Credits.rtf`）には、元の版の表記が残っています。
