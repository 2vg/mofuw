import mofuw
import middleware/router/mofuwRouter
import middleware/staticServe/mofuwStaticServe

# if you using router, router init and callback is this.
var
  router = newMofuwRouter()

mofuw.callback = proc(req: mofuwReq, res: mofuwRes) {.async.} =
  if not await serveStatic(req, res, "./"):
    await mofuwRouting(router, req, res)

# when router using, mofuw(HTTP METHOD NAME) call.
# and,
# ("/this/is/routing/path", proc(req: mofuwReq, res: mofuwRes) =
#   here is request handle process writing...
# )
router.mofuwGET("/", proc(req: mofuwReq, res: mofuwRes) {.async.} =
  await res.mofuw_send(makeResp(
    HTTP200,
    "text/html",
    "Hello World"
  ))
)

# this route for techempower benchmark. see README.md
router.mofuwGET("/plaintext", proc(req: mofuwReq, res: mofuwRes) {.async.} =
  await res.mofuw_send(makeResp(
    HTTP200,
    "text/plain",
    "Hello, World!"
  ))
)

router.mofuwGET("/user/@name", proc(req: mofuwReq, res: mofuwRes) {.async.} =
  await res.mofuw_send(makeResp(
    HTTP200,
    "text/plain",
    "Hello, " & req.params["name"] & "!"
  ))
)

mofuwRUN(8080, 128, 2048)