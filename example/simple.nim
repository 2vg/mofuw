import mofuw

proc handler(req: mofuwReq, res: mofuwRes) {.async.} =
  routes:
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

#####
# mofuwRun's Param
# port: int,
# backlog: int,
# bufferSize: int,
# cb: proc(req: mofuwReq, res: mofuwRes) {.async.}
# 
# but port, backlog, bufferSize is have default param.
# port = 8080, backlog = SOMAXCONN, bufferSize = 8KiB
# so, it is optional.
# for example code,
# mofuwRun(cb = handler)
#####

handler.mofuwRun(8080, 128, 512)