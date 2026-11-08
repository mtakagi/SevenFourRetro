# WKWebView への移行で置き換える機能（#27、#28）

スレの本文は旧 WebView（WebKit 1）で表示しています。WKWebView に移すとき（#28）に置き換えが必要な機能、置き換え先の目安、確認の手順をまとめます。

## #27 で分けたもの

タブと本文の境界を整理し、タブの管理を WebKit から切り離しました。

- **`TabbedWebView`**（タブバー）は WebKit を import しません。
  - タブの中身は `NSView<SFTabContent>` です（`SFTabContent.h`）。
  - 中身から受け取るのは、タブの名前（`-tabTitle`）と、読み込み中かどうか（`-isTabLoading`）だけです。
  - 変化は、中身が投げる `SFTabContentDidChangeNotification` で知ります。
  - クラス名は、`MainWindow.nib` が参照しているため残しています（#29 で見直す）。
- **`SFThreadView`**（本文）が `SFTabContent` を実装します。
  - WebKit の読み込みの進み具合の通知（開始・変化・完了）と、スレの差分更新の開始・終了を、`SFTabContentDidChangeNotification` にして投げます。
  - 本文の URL（`-pageURL`）とページ内検索（`-findString:forward:`）も、`SFThreadView` のメソッドにしました。
  - `SFMainWindowController` は、これらを通して本文を扱います（`-selectedThreadView`）。
- WKWebView 版の本文ビューは、`SFTabContent` と上のメソッドを実装すれば、タブバーを変えずに差し替えられます。

## まだ WebKit 1 に直接つながっているもの（#28 で置き換える）

| 機能 | 場所 | 今の WebKit 1 の API | WKWebView での置き換えの目安 |
| --- | --- | --- | --- |
| 本文とスキンの読み込み | `SFURLProtocol`（`sevenfour://` を `NSURLProtocol` で返す）、`SFThreadView -loadThreadWithURL:` | `NSURLProtocol` の登録、`-[WebFrame loadRequest:]` | WKWebView は `NSURLProtocol` を使わない。`WKURLSchemeHandler` で `sevenfour://`（スレ、`sevenfour://skin/`）を返す。メインスレッドの扱い（#9）も見直す |
| 差分の追加表示 | `SFThreadView -threadFinishParsing:` | `-stringByEvaluatingJavaScriptFromString:`（`#new` に HTML を追加） | `-evaluateJavaScript:completionHandler:`（非同期）。終わってから更新完了を伝える |
| 新着への移動 | `SFMainWindowController -webView:didFinishLoadForFrame:` | `sevenfour.scrollToNew()` を同期で実行 | `WKNavigationDelegate -webView:didFinishNavigation:` で非同期に実行 |
| リンクの扱い | `SFMainWindowController -webView:decidePolicyForNavigationAction:...` | `WebPolicyDelegate` | `WKNavigationDelegate -webView:decidePolicyForNavigationAction:decisionHandler:`。`sevenfour://internal/`（ID のポップアップ、レス番号から書き込み）、スレの URL（アプリ内で開く）、それ以外（ブラウザ） |
| リンクに乗せたときのポップアップ（安価、ID、画像） | `SFMainWindowController -webView:mouseDidMoveOverElement:modifierFlags:` | `WebUIDelegate`、`WebElementLinkURLKey` | WKWebView に同等の API はない。スキンの JavaScript で `mouseover` を拾い、`WKScriptMessageHandler` でアプリに伝える |
| レスのポップアップウインドウ | `SFPopUpWindowController` | 別の `WebView` に `-loadHTMLString:baseURL:`、文書ビューの高さでウインドウを合わせる | WKWebView に `-loadHTMLString:baseURL:`。高さは JavaScript（`document.body.scrollHeight`）で取る |
| ページ内検索 | `SFThreadView -findString:forward:` | `-searchFor:direction:caseSensitive:wrap:` | `-findString:withConfiguration:completionHandler:`（macOS 11 以降） |
| 戻る・進む | `SFThreadView -goBack` / `-goForward` | `WebView` の履歴 | `WKWebView` の履歴。戻ったあとのスレの取り直し（`thread_` のリセット）を合わせる |
| 本文の URL・ウインドウのタイトル | `SFThreadView -pageURL`、`-tabTitle`、`-webView:didStartProvisionalLoadForFrame:` | `WebDataSource`、`mainFrameTitle` | `URL` / `title` の KVO |
| JavaScript の alert | `-webView:runJavaScriptAlertPanelWithMessage:` | `WebUIDelegate` | `WKUIDelegate` |
| スキンに渡す情報 | `SFThreadHTMLFormatter`（`<SEVENFOUR_SUPPORT/>` でフォントと ID の数を埋め込む） | HTML の中の `<script>`（WebKit に依存しない） | そのまま使える。`sevenfour://skin/` の読み込みは上の `WKURLSchemeHandler` に合わせる |
| 画像の展開（クリック） | スキンの `sevenfour.extractImages()` | JavaScript（WebKit に依存しない） | そのまま使える。ただし ATS で HTTP の画像は読めない（現状も同じ） |
| フォーカスとスクロール | `TabbedWebView -selectContentAtIndex:`（本文を first responder にする） | `WebView` | `WKWebView` を first responder にする。#44 のように、レスポンダーチェーンを差し替えない |
| 文書ビューの大きさ | `SFThreadView -setFrameSize:` | `WebFrameView` をビューに合わせる | 不要（WKWebView は自分で合わせる） |

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
6. **ポップアップ**: 安価（`>>9` など）や ID にマウスを乗せると、レスのポップアップが出る。
7. **戻る・進む**: スレを 2 つ続けて開いたあと、戻ると前のスレに戻り、更新できる。
8. **ウインドウの大きさ**: ウインドウを広げたり縮めたりしても、本文がタブの下いっぱいに表示される。
