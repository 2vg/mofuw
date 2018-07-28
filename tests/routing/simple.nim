import ../../src/mofuw

routes:
  get "/":
    mofuwOK("Hello, World!")

  get "/user/{id}":
    mofuwOK("Hello, " & ctx.params("id") & "!")

  post "/create":
    mofuwOK("created: " & ctx.body)

newServeCtx(
  port = 8080,
  handler = mofuwHandler
).serve()