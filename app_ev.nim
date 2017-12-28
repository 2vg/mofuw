import mofuw_ev

var
  body =
    "HTTP/1.1 200 OK" & "\r\L" &
    "Connection: keep-alive" & "\r\L" &
    "Content-Length: " & $(11) & "\r\L" &
    "Content-Type: text/html; charset=utf-8" & "\r\L" & "\r\L" &
    "Hello World"

mofuw_GET("/", (proc(handle: ptr handle_t) =
  handle.mofuw_send(body)
))

mofuw_run(8080)