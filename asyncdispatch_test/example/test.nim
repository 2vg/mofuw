import mofuw

# if callback only, example this:
mofuw.callback = proc(req: mofuwReq, res: mofuwRes) {.async.} =
  if getPath(req) == "/plaintext":
    await res.mofuw_send(makeResp(
      HTTP200,
      "text/html",
      "Hello, World!"
    ))
  else:
    await res.mofuwSend(notFound())

  # this is case example:
  #[
  case getMethod(req)
  of "GET":
    if getPath(req) == "/plaintext":
      res.mofuw_send(makeResp(
        HTTP200,
        "text/html",
        "Hello World"
      ))
    else:
      res.mofuw_send(notFound())
  else:
    res.mofuw_send(badRequest())
  ]#

# this callback is best result for benchmark.

# sure, if you want to use like router,
# example router module made by me.
# see middleware/mofuw_router and,
# see example/routerExample/app.nim.

# event loop start.
# mofuwRUN(
#   PORT(= default is 8080),
#   BACKLOG(= default is OS's SOMAXCONN),
#   BUFFERSIZE(= default is 64KiB)
# )

mofuwRun(8080, 128, 512)