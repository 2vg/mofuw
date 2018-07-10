import ../../src/mofuw

setCert("cert.pem")
setKey("key.pem")

routes:
  get "/":
    mofuwOK("Hello, SSL World!")

mofuwRun(port = 443)