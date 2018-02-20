import mofuw, unicode
import middleware/router/mofuwRouter
import middleware/staticServe/mofuwStaticServe

# if you using router, router init and callback is this.
var
  router = newMofuwRouter()
  
mofuw.callback = proc(req: mofuwReq, res: mofuwRes) =
  if not serveStatic(req, res, "./"):
    mofuwRouting(router, req, res)

# when router using, mofuw(HTTP METHOD NAME) call.
# and,
# ("/this/is/routing/path", proc(req: mofuwReq, res: mofuwRes) =
#   here is request handle process writing...
# )
router.mofuwGET("/", proc(req: mofuwReq, res: mofuwRes) =
  res.mofuw_send(makeResp(
    HTTP200,
    "text/html",
    "Hello World"
  ))
)

# file response example
router.mofuwGET("/file", proc(req: mofuwReq, res: mofuwRes) =
  # for example, read file and processing...
  # let f = open("./dummy.txt", fmRead)
  # defer: close(f)
  # let results = do(f.readAll())
  # res.mofuw_send(makeResp(
  #   HTTP200,
  #   "text/html",
  #   readFile("./dummy.txt")
  # ))

  # this is direct read file and response soon.
  # but, not thinking about I/O error ;)
  res.mofuw_send(makeResp(
    HTTP200,
    "text/html",
    readFile("./index.html")
  ))
)

# this route for techempower benchmark. see README.md
router.mofuwGET("/plaintext", proc(req: mofuwReq, res: mofuwRes) =
  res.mofuw_send(makeResp(
    HTTP200,
    "text/plain",
    "Hello, World!"
  ))
)

router.mofuwGET("/user/@name", proc(req: mofuwReq, res: mofuwRes) =
  res.mofuw_send(makeResp(
    HTTP200,
    "text/plain",
    "Hello, " & req.params["name"] & "!"
  ))
)

mofuwRUN(8080, 128, 2048)