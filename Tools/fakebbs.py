#!/usr/bin/env python3
"""A fake 2ch/5ch-style server for trying SevenFour by hand, offline.

Serves synthetic data only, and never forwards anything to a real board.

  python3 Tools/fakebbs.py [--port 8765] [--delay SECONDS] [--post-delay SECONDS] [--log FILE]

  /bbsmenu.html                 board list with one board, /test/
  /test/subject.txt             two threads
  /test/dat/<number>.dat        DAT (Range requests answered with 206)
  /test/bbs.cgi                 posting, 5ch style:
      the first post gets a confirmation page that sets a cookie and has
      its own form (action ?guid=ON, the same time, submit value, hidden
      values); only that form sent back unchanged succeeds.
      A body containing ERRORTEST gets an error page.
      A body containing LOSTTEST is accepted, but the reply breaks off
      (the client can't tell whether the post was written).

--delay slows every GET down, e.g. to watch the spinning update icons.
--post-delay slows every POST down, e.g. to use the window while posting.
"""
import argparse
import datetime
import html
import http.server
import time
import urllib.parse

MENU = """<HTML><BODY>
<br><br><B>テスト</B><br>
<A HREF=http://{host}/test/>テスト板</A><br>
</BODY></HTML>
"""
SUBJECT = "1234567890.dat<>テストスレ (2)\n1234567891.dat<>新しいスレ (5)\n"
DAT = {
    "1234567890": "名無しさん<>sage<>2026/11/08(日) 00:00:00 ID:abc<> 1 つめ <>テストスレ\n"
                  "名無しさん<>sage<>2026/11/08(日) 00:00:01 ID:def<> 2 つめ <>\n",
    "1234567891": "".join(f"名無しさん<>sage<>2026/11/08(日) 00:00:0{i} ID:ghi<> {i} つめ <>{'新しいスレ' if i == 1 else ''}\n"
                          for i in range(1, 6)),
}
OK = "<html><head><title>書きこみました。</title></head><body>書きこみが終わりました。</body></html>"
ERROR = ("<html><head><title>ＥＲＲＯＲ！</title></head><body><ul><br></ul>"
         "<b>ERROR: テスト用のエラーです<br>もう一度どうぞ</b><form method=POST></form></body></html>")
CONFIRM = """<html><head><title>■ 書き込み確認 ■</title></head><body><!-- 2ch_X:cookie -->
<b>書き込み＆クッキー確認</b><br>投稿確認<br>この書き込みで本当にいいですか？<br>
<form method="POST" action="../test/bbs.cgi?guid=ON">
{hidden}<input type=hidden name="feature" value="confirmed">
<input type=submit value="上記全てを承諾して書き込む" name="submit"><br>
</form></body></html>"""


def sjis(text):
    return text.encode("shift_jis", "xmlcharrefreplace")


class Handler(http.server.BaseHTTPRequestHandler):
    confirmed = {}

    def log_message(self, fmt, *args):
        if self.server.log:
            with open(self.server.log, "a") as f:
                f.write(f"{datetime.datetime.now().isoformat()} {fmt % args}\n")

    def send(self, status, body, ctype="text/plain; charset=Shift_JIS", headers=()):
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        for name, value in headers:
            self.send_header(name, value)
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        time.sleep(self.server.delay)
        path = urllib.parse.urlparse(self.path).path
        if path == "/bbsmenu.html":
            return self.send(200, sjis(MENU.format(host=self.headers.get("Host"))), "text/html; charset=Shift_JIS")
        if path == "/test/subject.txt":
            return self.send(200, sjis(SUBJECT))
        if path.startswith("/test/dat/") and path.endswith(".dat"):
            data = sjis(DAT.get(path[len("/test/dat/"):-4], ""))
            if not data:
                return self.send(404, b"")
            rng = self.headers.get("Range", "")
            if rng.startswith("bytes="):
                start = int(rng[6:].rstrip("-") or 0)
                if start >= len(data):
                    return self.send(416, b"")
                return self.send(206, data[start:],
                                 headers=[("Content-Range", f"bytes {start}-{len(data) - 1}/{len(data)}")])
            return self.send(200, data)
        self.send(404, b"")

    def do_POST(self):
        time.sleep(self.server.post_delay)
        body = self.rfile.read(int(self.headers.get("Content-Length", 0))).decode("ascii", "replace")
        form = {k: v[0] for k, v in urllib.parse.parse_qs(body, encoding="shift_jis", keep_blank_values=True).items()}
        page = "text/html; charset=Shift_JIS"
        if "ERRORTEST" in form.get("MESSAGE", ""):
            return self.send(200, sjis(ERROR), page)
        if "LOSTTEST" in form.get("MESSAGE", ""):
            self.log_message("post accepted, reply cut: %r", form.get("MESSAGE"))
            body = sjis(OK)
            self.send_response(200)
            self.send_header("Content-Type", page)
            self.send_header("Content-Length", str(len(body) * 2))
            self.end_headers()
            self.wfile.write(body)
            self.close_connection = True
            return
        last = Handler.confirmed
        accepted = ("guid=ON" in self.path
                    and "MID=confirmed" in self.headers.get("Cookie", "")
                    and form.get("feature") == "confirmed"
                    and form.get("submit") == "上記全てを承諾して書き込む"
                    and all(form.get(k) == last.get(k) for k in ("time", "FROM", "mail", "MESSAGE")))
        if accepted:
            self.log_message("post accepted: %r", form.get("MESSAGE"))
            return self.send(200, sjis(OK), page)
        Handler.confirmed = form
        hidden = "".join(f'<input type=hidden name="{k}" value="{html.escape(form.get(k, ""))}">\n'
                         for k in ("FROM", "mail", "MESSAGE", "bbs", "time", "key"))
        self.send(200, sjis(CONFIRM.format(hidden=hidden)), page, [("Set-Cookie", "MID=confirmed; path=/")])


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--delay", type=float, default=0.0, help="seconds to wait before answering a GET")
    parser.add_argument("--post-delay", type=float, default=0.0, help="seconds to wait before answering a POST")
    parser.add_argument("--log", help="append requests to this file")
    args = parser.parse_args()
    server = http.server.ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    server.delay, server.post_delay, server.log = args.delay, args.post_delay, args.log
    print(f"fakebbs: http://127.0.0.1:{args.port}/bbsmenu.html", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
