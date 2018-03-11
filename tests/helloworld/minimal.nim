import mofuw
proc handler(req: mofuwReq, res: mofuwRes) {.async.} =
  routes:
    get "/":
      mofuwResp(HTTP200, "text/plain", "Hello, World!")
handler.mofuwRun()