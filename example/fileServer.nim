import mofuw

# want static file serve, use routeStatic.
# for example,
#
# routesStatic "/want/serve/path":
#   discard (or something route.)

proc handler(req: mofuwReq, res: mofuwRes) {.async.} =
  routesStatic "./":
    discard

# routesStatic "./":
#   post "/user/create":
#     echo "created: " & req.body

handler.mofuwRun(8080, 128, 512)