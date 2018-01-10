import mofuw_ev
import lib/httputils

mofuw_GET("/", (proc(handle: ptr handle_t) =
  handle.mofuw_send(makeResp(
    HTTP200,
    "text/plain",
    "Hello World"
  ))
))

mofuw_run(8080)