import ../../src/mofuw

routes:
  get "/":
    mofuwOK("hello, world!")

newServeCtx(
  port = 8080,
  handler = mofuwHandler
).serve()
