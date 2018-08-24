import ../../src/mofuw

proc handler(ctx: MofuwCtx) {.async.} =
  if ctx.getPath == "/":
    mofuwOK("Hello, World!")
  else:
    mofuwResp(HTTP404, "text/plain", "Route: " & ctx.getPath & " Not Found")

newServeCtx(
  port = 8080,
  handler = handler
).serve()
