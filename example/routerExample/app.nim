import mofuw
import middleware/router/mofuwRouter

# if you using router, router init and callback is this.
var
  router = newMofuwRouter()
  
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

router.mofuwGET("/user/@name", proc(req: ptr mofuwReq, res: ptr mofuwRes) =
  res.mofuw_send(makeResp(
    HTTP200,
    "text/plain",
    "Hello, " & req.params["name"] & "!"
  ))
)

mofuwRUN(8080, 128, 2048)