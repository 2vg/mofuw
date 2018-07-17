import ../../src/mofuw

routes:
  get "/":
    mofuwOK("Hello, World!")

  get "/user/{id}":
    mofuwOK("Hello, " & req.params("id") & "!")

  post "/create":
    mofuwOK("created: " & req.body)

mofuwRun(8080)