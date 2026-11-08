# WKWebView への移行で置き換える機能（#27、#28）

スレの本文は #28 で WKWebView に移しました。レスのポップアップウインドウはまだ旧 WebView（WebKit 1）です。置き換えた機能、残っている機能、確認の手順をまとめます。

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
- WKWebView 版の本文ビューは、`SFTabContent` と上のメソッドを実装すれば、タブバーを変えずに差し替えられます。

## #28 で移したもの（本文）

本文（`SFThreadView`）は `WKWebView` のサブクラスになりました。

| 機能 | WKWebView での実装 |
| --- | --- |
| 本文とスキンの読み込み | `SFThreadSchemeHandler`（`WKURLSchemeHandler`）が `sevenfour://` を返す。スレは更新が終わってから（`SFThreadDidFinishUpdatingNotification`）HTML を返す。すべてメインスレッドで動く |
| 差分の追加表示 | `-evaluateJavaScript:completionHandler:` で `#new` に追加し、終わってからタブのスピナーを止める |
| 新着への移動 | `-webView:didFinishNavigation:` で `sevenfour.scrollToNew()` を実行 |
| リンクの扱い | `-webView:decidePolicyForNavigationAction:decisionHandler:` から、持ち主（`SFMainWindowController`）の `-threadView:shouldLoadURL:inBackground:` に聞く。⌘ は `-[WKNavigationAction modifierFlags]` で見る |
| リンクに乗せたときのポップアップ | ユーザースクリプトが `mouseover` でリンクの URL・文字列・Option を `WKScriptMessageHandler`（`sevenfourHover`）に送り、`-threadView:mouseOverURL:label:option:` で伝える |
| ページ内検索 | `-findString:withConfiguration:completionHandler:` |
| 戻る・進む | `WKWebView` の履歴。`-webView:didCommitNavigation:` で表示中のスレ（`thread_`）を合わせる |
| 本文の URL・タブの名前 | `URL`、`title`。`title` と `loading` を KVO で見て `SFTabContentDidChangeNotification` を投げる |
| JavaScript の alert | `WKUIDelegate`（ログに出す） |

`SFURLProtocol`（`NSURLProtocol`）は、まだ WebKit 1 のレスのポップアップウインドウのために残しています。スキンのファイルの場所は `+[SFURLProtocol pathOfSkinFile:]` で両方が共有します。

## まだ WebKit 1 に残っているもの（#28 の続きで置き換える）

| 機能 | 場所 | 今の WebKit 1 の API | WKWebView での置き換えの目安 |
| --- | --- | --- | --- |
| レスのポップアップウインドウ | `SFPopUpWindowController`（`PopUpWindow.nib` の `WebView`） | 別の `WebView` に `-loadHTMLString:baseURL:`、文書ビューの高さでウインドウを合わせる。リンクとホバーは `SFMainWindowController` の `WebPolicyDelegate` / `WebUIDelegate` | WKWebView に `-loadHTMLString:baseURL:`。高さは JavaScript（`document.body.scrollHeight`）で取る。リンクとホバーは本文と同じ `-shouldLoadURL:inBackground:` / `-hoverURL:label:option:` を使う |
| `sevenfour://` の `NSURLProtocol` | `SFURLProtocol` | `NSURLProtocol` の登録 | ポップアップを移したら削除する |
| 非推奨警告の抑止 | `project.yml` の `DISABLE_LEGACY_WEBKIT_DEPRECATIONS` | — | WebKit 1 をなくしたら削除する |

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
7. **戻る・進む**: スレを 2 つ続けて開いたあと、戻ると前のスレに戻り、更新できる。
8. **ウインドウの大きさ**: ウインドウを広げたり縮めたりしても、本文がタブの下いっぱいに表示される。
