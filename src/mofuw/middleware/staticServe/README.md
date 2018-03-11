# mofuwStaticServing

> static file serving module for mofuw.

### usage

```nim
import mofuw
import middleware/router/mofuwRouter
import middleware/staticServe/mofuwStaticServe

# without routing,
mofuw.callback = proc(req: ptr mofuwReq, res: ptr mofuwRes) =
  if not serveStatic(req, res, "./"):
    if getPath(req) == "/hoge":
      res.mofuw_send(makeResp(
        HTTP200,
        "text/html",
        "Yay, HOGE!"
      ))
    else:
      res.mofuw_send(notFound())

# with routing,
mofuw.callback = proc(req: ptr mofuwReq, res: ptr mofuwRes) =
  if not serveStatic(req, res, "./"):
    mofuwRouting(router, req, res)
```