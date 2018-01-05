import mofuw_uv
import lib/httputils

mofuw_GET("/", proc(req: ptr http_req, res: ptr http_res) =
  res.mofuw_send(makeResp(
    HTTP200,
    "text/plain",
    "Hello World"
  ))
)

mofuw_GET("/test", proc(req: ptr http_req, res: ptr http_res) =
  res.mofuw_send(makeResp(
    HTTP200,
    "text/plain",
    "fooooo"
  ))
)

mofuw_run(8080)
