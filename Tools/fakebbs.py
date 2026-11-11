#!/usr/bin/env python3
"""A fake 2ch/5ch-style server for trying SevenFour by hand, offline.

Serves synthetic data only, and never forwards anything to a real board.

  python3 Tools/fakebbs.py [--port 8765] [--delay SECONDS] [--post-delay SECONDS] [--log FILE]

  /bbsmenu.html                 board list: テスト板 (/test/) and, for reading
                                many threads (#22), 読み進め板 (/yomu/) and
                                雑談板 (/zatsu/)
  /<board>/subject.txt          the board's threads
  /<board>/dat/<number>.dat     DAT (Range requests answered with 206)
  /<board>/bbs.cgi              posting, 5ch style:
      the first post gets a confirmation page that sets a cookie and has
      its own form (action ?guid=ON, the same time, submit value, hidden
      values); only that form sent back unchanged succeeds.
      An accepted post is added to the end of its thread (and moves the
      thread to the top of the list unless mail is sage), so updating
      the thread shows it as a new message. Nothing is saved: restarting
      the server starts again from the same data.
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

# The boards, in the order of the board list. Every thread is made from
# fixed rules, so the data is the same on every run and for anyone who
# compares another client against it (mtakagi/SevenFour#112).
CATEGORY = "テスト"
BOARD_TITLES = {"test": "テスト板", "yomu": "読み進め板", "zatsu": "雑談板"}
MENU_TEMPLATE = """<HTML><BODY>
<br><br><B>{category}</B><br>
{links}</BODY></HTML>
"""


def message(name, mail, day, second, ident, body, title=""):
    time_text = f"2026/11/{day:02d}(日) 00:{second // 60:02d}:{second % 60:02d}"
    return f"{name}<>{mail}<>{time_text} ID:{ident}<> {body} <>{title}\n"


def make_thread(board, index, count):
    """A thread of count messages; every tenth one answers the one before."""
    title = f"{BOARD_TITLES[board]}のスレ {index:02d}"
    if board == "yomu" and index == 1:
        title = "長いスレ（300 レス）"
    lines = []
    for n in range(1, count + 1):
        body = f"{title} の {n} つめ"
        if n % 10 == 0:
            body = f"&gt;&gt;{n - 1}<br>{body}"
        lines.append(message("名無しさん", "sage", 8, n, f"id{index:02d}{n % 7}", body, title if n == 1 else ""))
    return title, "".join(lines)


def make_boards():
    boards = {}
    # テスト板: the two threads the smoke test and the docs use.
    boards["test"] = [
        ["1234567890", "テストスレ",
         message("名無しさん", "sage", 8, 0, "abc", "1 つめ", "テストスレ")
         + message("名無しさん", "sage", 8, 1, "def", "2 つめ")],
        ["1234567891", "新しいスレ",
         "".join(message("名無しさん", "sage", 8, i, "ghi", f"{i} つめ", "新しいスレ" if i == 1 else "")
                 for i in range(1, 6))],
    ]
    # 読み進め板: 40 threads, more than a window shows, the first one long.
    # 雑談板: 30 threads, to leave a board and come back.
    for board, threads in (("yomu", 40), ("zatsu", 30)):
        boards[board] = []
        for i in range(1, threads + 1):
            count = 300 if (board == "yomu" and i == 1) else 3 + (i * 7) % 25
            title, dat = make_thread(board, i, count)
            number = str((1767225600 if board == "yomu" else 1767312000) + i * 60)
            boards[board].append([number, title, dat])
    return boards


BOARDS = make_boards()


def subject_txt(board):
    return "".join(f"{number}.dat<>{title} ({dat.count(chr(10))})\n" for number, title, dat in BOARDS[board])


def find_thread(board, number):
    for thread in BOARDS.get(board, []):
        if thread[0] == number:
            return thread
    return None


OK = "<html><head><title>書きこみました。</title></head><body>書きこみが終わりました。</body></html>"
ERROR = ("<html><head><title>ＥＲＲＯＲ！</title></head><body><ul><br></ul>"
         "<b>ERROR: テスト用のエラーです<br>もう一度どうぞ</b><form method=POST></form></body></html>")
# Long notes, as 5ch's confirmation page has (its terms of posting), so the
# confirmation dialog can be checked with a long message (#66). Synthetic.
TERMS = "<br>".join(
    f"・テスト用の注意書き {i}。確認ダイアログで長い文章が途中で切れないことを確かめるための、意味のない文章です。"
    for i in range(1, 13))
CONFIRM = """<html><head><title>■ 書き込み確認 ■</title></head><body><!-- 2ch_X:cookie -->
<b>書き込み＆クッキー確認</b><br>投稿確認<br>この書き込みで本当にいいですか？<br>
{terms}
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
            host = self.headers.get("Host")
            links = "".join(f"<A HREF=http://{host}/{board}/>{title}</A><br>\n"
                            for board, title in BOARD_TITLES.items())
            return self.send(200, sjis(MENU_TEMPLATE.format(category=CATEGORY, links=links)),
                             "text/html; charset=Shift_JIS")
        parts = path.strip("/").split("/")
        if len(parts) == 2 and parts[0] in BOARDS and parts[1] == "subject.txt":
            return self.send(200, sjis(subject_txt(parts[0])))
        if len(parts) == 3 and parts[0] in BOARDS and parts[1] == "dat" and parts[2].endswith(".dat"):
            thread = find_thread(parts[0], parts[2][:-4])
            if not thread:
                return self.send(404, b"")
            data = sjis(thread[2])
            rng = self.headers.get("Range", "")
            if rng.startswith("bytes="):
                start = int(rng[6:].rstrip("-") or 0)
                if start >= len(data):
                    return self.send(416, b"")
                return self.send(206, data[start:],
                                 headers=[("Content-Range", f"bytes {start}-{len(data) - 1}/{len(data)}")])
            return self.send(200, data)
        self.send(404, b"")

    def add_message(self, form):
        """Adds an accepted post to its thread, as bbs.cgi would."""
        board = BOARDS.get(form.get("bbs", ""))
        thread = find_thread(form.get("bbs", ""), form.get("key", ""))
        if not thread:
            return
        n = thread[2].count("\n") + 1
        # Escaped like bbs.cgi does, so "<>" in any field can't split the DAT line.
        def field(value):
            return html.escape(value).replace("\r", "").replace("\n", " ")
        text = html.escape(form.get("MESSAGE", "")).replace("\r", "").replace("\n", "<br>")
        thread[2] += message(field(form.get("FROM", "")) or "名無しさん", field(form.get("mail", "")),
                             8, n, "post", text)
        if form.get("mail") != "sage":
            board.remove(thread)
            board.insert(0, thread)

    def do_POST(self):
        time.sleep(self.server.post_delay)
        body = self.rfile.read(int(self.headers.get("Content-Length", 0))).decode("ascii", "replace")
        form = {k: v[0] for k, v in urllib.parse.parse_qs(body, encoding="shift_jis", keep_blank_values=True).items()}
        page = "text/html; charset=Shift_JIS"
        if "ERRORTEST" in form.get("MESSAGE", ""):
            return self.send(200, sjis(ERROR), page)
        if "LOSTTEST" in form.get("MESSAGE", ""):
            self.log_message("post accepted, reply cut: %r", form.get("MESSAGE"))
            # Written like any accepted post: updating the thread shows it.
            self.add_message(form)
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
            self.add_message(form)
            return self.send(200, sjis(OK), page)
        Handler.confirmed = form
        hidden = "".join(f'<input type=hidden name="{k}" value="{html.escape(form.get(k, ""))}">\n'
                         for k in ("FROM", "mail", "MESSAGE", "bbs", "time", "key"))
        self.send(200, sjis(CONFIRM.format(hidden=hidden, terms=TERMS)), page, [("Set-Cookie", "MID=confirmed; path=/")])


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
