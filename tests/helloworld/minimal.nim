import mofuw
proc handler(req: mofuwReq, res: mofuwRes) {.async.} =
  routes:
    get "/":
      mofuwOK("Hello, World!")
handler.mofuwRun()