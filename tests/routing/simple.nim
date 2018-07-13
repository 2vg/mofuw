import ../../src/mofuw

routes:
  get "/":
    mofuwOK("Hello, World!")

  get "/user/{id}":
    mofuwOK("Hello, " & ctx.params("id") & "!")

  post "/create":
    mofuwOK("created: " & ctx.body)

mofuwRun(8080)