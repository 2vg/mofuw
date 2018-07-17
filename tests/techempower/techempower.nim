import ../../src/mofuw

proc handler(ctx: MofuwCtx) {.async.} =
  if ctx.getPath == "/plaintext":
    mofuwOK("Hello, World!")
  else:
   mofuwResp(HTTP404, "tet/plain", "Not Found")

newServeCtx(
  port = 8080,
  handler = handler
).serve()