import ../../src/mofuw
routes:
  get "/":
    mofuwOK("Hello, World")
mofuwRun(8080)