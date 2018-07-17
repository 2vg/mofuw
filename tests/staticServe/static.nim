import ../../src/mofuw

routes:
  serve("public")

  get "/foo":
    mofuwOK("yay")

newServeCtx(
  port = 8080,
  handler = mofuwHandler
).serve()