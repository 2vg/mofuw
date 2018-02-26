import mofuw

proc handler(req: mofuwReq, res: mofuwRes) {.async.} =
  routes:
    get "/":
      await res.cacheResp(getPath(req),
        HTTP200,
        "text/plain",
        "Hello World!"
      )

handler.mofuwRun(8080, 128, 512)