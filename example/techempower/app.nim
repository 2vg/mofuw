import mofuw
import middleware/mofuw_router
import lib/httputils

var
  router = newMofuwRouter()

#[
# if callback only, example this:

```
mofuw.callback = proc(req: ptr mofuwReq, res: ptr mofuwRes) =
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
```
]#

# if you using router, callback is this.
mofuw.callback = proc(req: ptr mofuwReq, res: ptr mofuwRes) =
  mofuwRouting(router, req, res)

# when router using, mofuw(HTTP METHOD NAME) call.
# and,
# ("/this/is/routing/path", proc(req: ptr mofuwReq, res: ptr mofuwRes) =
#   here is request handle process writing...
# )
router.mofuwGET("/", proc(req: ptr mofuwReq, res: ptr mofuwRes) =
  res.mofuw_send(makeResp(
    HTTP200,
    "text/html",
    "Hello World"
  ))
)

# this route for techempower benchmark. see README.md
router.mofuwGET("/plaintext", proc(req: ptr mofuwReq, res: ptr mofuwRes) =
  res.mofuw_send(makeResp(
    HTTP200,
    "text/plain",
    "Hello, World!"
  ))
)

# event loop start.
# mofuwRUN(
#   PORT(= default is 8080),
#   BACKLOG(= default is OS's SOMAXCONN),
#   BUFFERSIZE(= default is 64KiB)
# )
mofuwRUN(8080, 128, 2048)
