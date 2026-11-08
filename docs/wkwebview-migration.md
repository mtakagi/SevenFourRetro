# WKWebView への移行（#27、#28）

スレの本文とレスのポップアップウインドウを、旧 WebView（WebKit 1）から WKWebView に移しました（#28）。WebKit 1 はもう使っていません。置き換えた機能と確認の手順をまとめます。

## #27 で分けたもの

タブと本文の境界を整理し、タブの管理を WebKit から切り離しました。

- **`TabbedWebView`**（タブバー）は WebKit を import しません。
  - タブの中身は `NSView<SFTabContent>` です（`SFTabContent.h`）。
  - 中身から受け取るのは、タブの名前（`-tabTitle`）と、読み込み中かどうか（`-isTabLoading`）だけです。
  - 変化は、中身が投げる `SFTabContentDidChangeNotification` で知ります。
  - クラス名は、`MainWindow.nib` が参照しているため残しています（#29 で見直す）。
- **`SFThreadView`**（本文）が `SFTabContent` を実装します。
  - 読み込みの開始・終了とタイトルの変化、スレの差分更新の開始・終了を、`SFTabContentDidChangeNotification` にして投げます。
  - 本文の URL（`-pageURL`）とページ内検索（`-findString:forward:`）も、`SFThreadView` のメソッドにしました。
  - `SFMainWindowController` は、これらを通して本文を扱います（`-selectedThreadView`）。
- これにより、#28 で本文を WKWebView に替えたときも、タブバーは変えずに済みました。

## #28 で移したもの

本文（`SFThreadView`）とレスのポップアップウインドウは、どちらも `SFPageView`（`WKWebView` のサブクラス）で表示します。`SFPageView` が `sevenfour://` の読み込み、リンク、マウスを乗せたリンク、ページ内検索、JavaScript の alert を受け持ち、`SFThreadView` はスレとタブの部分を足します。

| 機能 | WKWebView での実装 |
| --- | --- |
| 本文とスキンの読み込み | `SFThreadSchemeHandler`（`WKURLSchemeHandler`）が `sevenfour://` を返す。スレは更新が終わってから（`SFThreadDidFinishUpdatingNotification`）HTML を返す。すべてメインスレッドで動く |
| 差分の追加表示 | `-evaluateJavaScript:completionHandler:` で `#new` に追加し、終わってからタブのスピナーを止める |
| 新着への移動 | `-webView:didFinishNavigation:` で `sevenfour.scrollToNew()` を実行 |
| リンクの扱い | `-webView:decidePolicyForNavigationAction:decisionHandler:` から、持ち主（`SFMainWindowController`）の `-pageView:shouldLoadURL:inBackground:` に聞く。⌘ は `-[WKNavigationAction modifierFlags]` で見る |
| リンクに乗せたときのポップアップ | ユーザースクリプトが `mouseover` でリンクの URL・文字列・Option を `WKScriptMessageHandler`（`sevenfourHover`）に送り、`-pageView:mouseOverURL:label:option:` で伝える |
| ページ内検索 | `-findString:withConfiguration:completionHandler:` |
| 戻る・進む | `WKWebView` の履歴。`-webView:didCommitNavigation:` で表示中のスレ（`thread_`）を合わせる |
| 本文の URL・タブの名前 | `URL`、`title`。`title` と `loading` を KVO で見て `SFTabContentDidChangeNotification` を投げる |
| JavaScript の alert | `WKUIDelegate`（ログに出す） |
| レスのポップアップウインドウ | `SFPopUpWindowController` をコードで作る（`PopUpWindow.nib` は削除）。`TemporaryPanel` に `SFPageView` を置き、`-loadHTMLString:baseURL:` で表示する。`baseURL` は本文のページの URL なので、ポップアップの中の安価（`#N`）からさらにポップアップできる。高さはユーザースクリプト（`ResizeObserver`）から受け取って合わせる |
| テンプレートの読み込み | `SFThreadHTMLFormatter` はスキンのファイルを直接読む（`+pathOfSkinFile:`）。`sevenfour://` を `NSURLProtocol` で読むのはやめた |

`SFURLProtocol`（`NSURLProtocol`）と、`project.yml` の `DISABLE_LEGACY_WEBKIT_DEPRECATIONS` は削除しました。

## 確認の手順

偽サーバーと一時的な HOME で確認します（`AGENTS.md` の「手動での確認」）。

```sh
python3 Tools/fakebbs.py --port 8765
Tools/run-app-with-test-home.sh
```

`docs/retro-reading-flow.md` の 1〜9 をたどったうえで、次を確認します。

1. **表示**: 「読み進め板」のスレを開くと、スキン（タイトル、All・Top・New、レスの枠）付きで本文が出る。タブの名前がスレタイになる。
2. **背面タブ**: ⌘クリックで開いたタブに切り替えると本文が出て、最後までスクロールできる（#44）。
3. **更新**: ⌘R でスレを更新すると、タブにスピナーが出て、終わると消える。書き込むと新着が `#new` に追加される。
4. **ページ内検索**: 「検索...」で語を入れ、次・前を検索すると、該当箇所が選択される（前を検索は #27 で直した）。
5. **リンク**: 本文中のスレの URL はアプリのタブで開き、それ以外のリンクはブラウザで開く。レス番号をクリックすると、`>>N` 付きの書き込みウインドウが出る。
6. **ポップアップ**: 安価（`>>9` など）にマウスを乗せると、レスのポップアップが出る。ID をクリックすると、同じ ID のレスのポップアップが出る。
   - ポップアップは枠と影付きで、高さが中身に合う。画面より高いときは画面に収まり、スクロールできる。
   - ポップアップの中の安価にマウスを乗せると、さらにポップアップが出る。
   - マウスをポップアップの外に出すと閉じる。
7. **戻る・進む**: スレを 2 つ続けて開いたあと、戻ると前のスレに戻り、更新できる。
8. **ウインドウの大きさ**: ウインドウを広げたり縮めたりしても、本文がタブの下いっぱいに表示される。
