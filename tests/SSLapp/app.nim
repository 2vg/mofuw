import ../../src/mofuw, threadpool

let sslServer = newServeCtx(
  port = 443
)

sslServer.addCertAndKey(
  servername = "example.com",
  cert = "cert.pem",
  key = "key.pem"
)

block:
  vhosts sslServer:
    host "example.com":
      mofuwOK("Hello, World!")

let httpServer = newServeCtx(
  port = 80
)

vhosts httpServer:
  host "example.com":
    await ctx.mofuwSend(redirectTo("https://example.com"))

sync()