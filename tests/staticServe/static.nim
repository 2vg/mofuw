import ../../src/mofuw

routes:
  serve("public")

  get "/foo":
    mofuwOK("yay")

mofuwRun(8080)