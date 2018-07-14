import ../../src/mofuw

vhosts:
  host "localhost:8080":
    mofuwOk("I'm local :)")
  host "example.com":
    mofuwOk("Hello, example!")

mofuwRun(8080)

# With SSL,
#
# -d:ssl
#
# addCertAndKey(
#   cert = "cert.pem",
#   key = "kep.pem"
#)

# mofuwRunWithSSL(4443)