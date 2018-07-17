import ../../src/mofuw

let server1 = newServeCtx(
  port = 8080
)

vhosts server1:
  host "localhost:8080":
    mofuwOk("I'm local :)")
  host "example.com":
    mofuwOk("Hello, example!")

let server2 = newServeCtx(
  port = 8081
)

vhosts server2:
  host "localhost:8081":
    mofuwOk("Second server :)")