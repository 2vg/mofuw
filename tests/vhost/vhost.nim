import ../../src/mofuw

let server = newServeCtx(
  port = 8080
)

vhosts server:
  host "localhost:8080":
    mofuwOk("I'm local :)")
  host "example.com":
    mofuwOk("Hello, example!")