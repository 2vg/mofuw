import mofuw_ev

mofuw_GET("/", (proc(handle: ptr handle_t) =
  var
    body =
      "HTTP/1.1 200 OK" & "\r\L" &
      "Connection: keep-alive" & "\r\L" &
      "Content-Length: " & $(400) & "\r\L" &
      "Content-Type: text/plain; charset=utf-8" & "\r\L" & "\r\L"

  for i in 0 ..< 400:
    body.add("a")

  handle.mofuw_send(body)
))

mofuw_run(8080)