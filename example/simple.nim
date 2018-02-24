import mofuw

mofuw.callback = proc(req: mofuwReq, res: mofuwRes) {.async.} =
  routesWithPattern:
    get "/":
      await res.mofuwSend(makeResp(
        HTTP200,
        "text/plain",
        "Hello, World!"
      ))

    get "/user/@id":
      await res.mofuwSend(makeResp(
        HTTP200,
        "text/plain",
        "Hello, " & req.params["id"] & "!"
      ))

    post "/create":
      await res.mofuwSend(makeResp(
        HTTP200,
        "text/plain",
        "created: " & req.body
      ))

mofuwRUN(8080, 128, 512)