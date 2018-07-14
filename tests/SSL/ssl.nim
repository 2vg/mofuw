import ../../src/mofuw

addCertAndKey(
  cert = "cert.pem",
  key = "key.pem")

routes:
  get "/":
    mofuwOK("Hello, SSL World!")

mofuwRunWithSSL(port = 443)