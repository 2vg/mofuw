import mofuw

proc handler(req: ptr http_req, res: ptr http_res) =
  mofuw_send(res, testbody)

mofuw_init(8080)

mofuw_run(handler)