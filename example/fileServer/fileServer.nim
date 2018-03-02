import mofuw

# want static file serve, use routeStatic.
# for example,
#
# routes "/want/serve/path":
#   discard (or something route.)

proc handler(req: mofuwReq, res: mofuwRes) {.async.} =
  routes "./":
    discard

# routes "./":
#   post "/user/create":
#     echo "created: " & req.body

handler.mofuwRun(8080, 128, 512)