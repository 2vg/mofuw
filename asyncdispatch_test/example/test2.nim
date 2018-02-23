import mofuw

mofuw.callback = proc(req: mofuwReq, res: mofuwRes) {.async.} =
  routes:
    get "/":
      await res.mofuwSend(makeResp(
        HTTP200,
        "text/plain",
        "Hello, World!"
      ))

mofuwRUN(8080, 128, 2048)