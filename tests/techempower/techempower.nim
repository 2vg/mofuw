import ../../src/mofuw

mofuwHandler:
  if req.getPath == "/plaintext":
    mofuwResp(HTTP200, "text/plain", "Hello, World!")
  else:
    mofuwResp(HTTP404, "text/plain", "NOT FOUND")

mofuwHandler.mofuwRun(8080)