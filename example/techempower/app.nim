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

mofuw.callback = proc(req: ptr mofuwReq, res: ptr mofuwRes) =
  mofuwRouting(router, req, res)

router.mofuwGET("/", proc(req: ptr mofuwReq, res: ptr mofuwRes) =
  res.mofuw_send(makeResp(
    HTTP200,
    "text/html",
    "Hello World"
  ))
)

router.mofuwGET("/plaintext", proc(req: ptr mofuwReq, res: ptr mofuwRes) =
  res.mofuw_send(makeResp(
    HTTP200,
    "text/plain",
    "Hello, World!"
  ))
)

mofuwRUN(8080)
