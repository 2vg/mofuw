import mofuw
import osproc
import posix
import os

var 
  port = 8080

  body: cstring =
    "HTTP/1.1 200 OK" & "\r\L" &
    "Connection: keep-alive" & "\r\L" &
    "Content-Length: 11"  & "\r\L" &
    "Content-Type: text/plain; charset=utf-8" & "\r\L" & "\r\L" &
    "Hello World"

proc th() =
  mofuw_GET("/", proc(req: ptr http_req, res: ptr http_res) =
    res.mofuw_send(body)
  )

  mofuw_run(port, 1024)

for i in 0 ..< countProcessors():
  let pid = fork()
  if pid == 0:
    th()
    quit(0)

while true:
  sleep(10000)