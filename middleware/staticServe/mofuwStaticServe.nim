import os, ospaths, mimetypes, uri, asyncfile

proc fileResp(res: mofuwRes, filePath, file: string) {.async.}=
  let (_, _, ext) = splitFile(filePath)

  if ext == "":
    await res.mofuwSend(makeResp(
      HTTP200,
      "text/plain",
      file
    ))
  else:
    let mime = newMimetypes()

    await res.mofuwSend(makeResp(
      HTTP200,
      mime.getMimetype(ext[1 .. ^1], default = "application/octet-stream"),
      file
    ))

proc serveStatic*(req: mofuwReq, res: mofuwRes, rootPath: string): Future[bool] {.async.} =
  var
    state = 0
    reqPath = getPath(req)
    filePath = rootPath

  for k, v in reqPath:
    if v == '.':
      if reqPath[k+1] == '.':
        await res.mofuwSend(badRequest())
        return true

  if filePath[^1] != '/':
    filePath.add("/")
    filePath.add(reqPath[state .. ^1])
  else:
    filePath.add(reqPath[state .. ^1])

  if filePath[^1] != '/':
    if existsDir(filePath):
      # Since the Host header should always exist,
      # Nil check is not done here
      let host = getHeader(req, "Host")

      reqPath.add("/")

      await res.mofuwSend(redirectTo(
        "http://" / host / reqPath
      ))

      return true
    if fileExists(filePath):
      let
        f = openAsync(filePath, fmRead)
        file = await f.readAll()
      close(f)
      await res.fileResp(filePath, file)
      return true
    else:
      return false
  else:
    filePath.add("index.html")
    if fileExists(filePath):
      let
        f = openAsync(filePath, fmRead)
        file = await f.readAll()
      close(f)
      await res.fileResp(filePath, file)
      return true
    else:
      return false