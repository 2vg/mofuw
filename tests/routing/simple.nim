import mofuw

proc handler(req: mofuwReq, res: mofuwRes) {.async.} =
  routes:
    get "/":
      mofuwResp(
        HTTP200,
        "text/plain",
        "Hello, World!")

    get "/user/@id/?":
      mofuwResp(
        HTTP200,
        "text/plain",
        "Hello, " & req.params("id") & "!")

    post "/create":
      mofuwResp(
        HTTP200,
        "text/plain",
        "created: " & req.body)

#####
# mofuwRun's Param
# cb: proc(req: mofuwReq, res: mofuwRes) {.async.}
# port: int,
# backlog: int,
# bufferSize: int,
# 
# but port, backlog, bufferSize is have default param.
# port = 8080, backlog = SOMAXCONN, bufferSize = 8KiB
# so, it is optional.
# for example code,
# handler.mofuwRun() or mofuwRun(handler)
#####

handler.mofuwRun(8080, 128, 512)