import mofuw
import lib/httputils

mofuwGET("/", proc(req: ptr http_req, res: ptr http_res) =
  res.mofuw_send(makeResp(
    HTTP200,
    "text/plain",
    "Hello World"
  ))
)

mofuwRUN(8080)
