import mofuw

var 
  port = 8080

  body: cstring =
    "HTTP/1.1 200 OK" & "\r\L" &
    "Connection: keep-alive" & "\r\L" &
    "Content-Length: 11"  & "\r\L" &
    "Content-Type: text/plain; charset=utf-8" & "\r\L" & "\r\L" &
    "Hello World"

proc handler(req: ptr http_req, res: ptr http_res) =
  res.mofuw_send(body)

mofuw_init(port)

mofuw_run(handler)