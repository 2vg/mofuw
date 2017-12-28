import mofuw
import osproc
import posix
import os

var 
  port = 8080

  body: string =
    "HTTP/1.1 200 OK" & "\r\L" &
    "Connection: keep-alive" & "\r\L" &
    "Content-Length: " & $(1024 * 1024) & "\r\L" &
    "Content-Type: text/plain; charset=utf-8" & "\r\L" & "\r\L"

for i in 0 ..< 1024 * 1024:
  body.add("a")

mofuw_GET("/", proc(req: ptr http_req, res: ptr http_res) =
  res.mofuw_send(body)
)

mofuw_run(port)