# mofuwStaticServing

> static file serving module for mofuw.

### usage

```nim
import
  mofuw,
  mofuw/middleware/staticServe/mofuwStaticServe

# want static file serve, use routeStatic.
# for example,
#
# routes "/want/serve/path":
#   discard (or something route.)

proc handler(req: mofuwReq, res: mofuwRes) {.async.} =
  routesStatic "./":
    discard

# routes "./":
#   post "/user/create":
#     echo "created: " & req.body

handler.mofuwRun(8080)
```