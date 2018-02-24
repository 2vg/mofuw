import mofuw, os, ospaths, mimetypes, uri, asyncfile

proc serveStatic*(req: mofuwReq, res: mofuwRes, rootPath: string): Future[bool] {.async.} =
  var
    state = 0
    reqPath = getPath(req)
    fileExt = ""
    filePath = rootPath
    file: string

  for k, v in reqPath:
    if v == '.':
      if reqPath[k+1] == '.':
        await res.mofuw_send(badRequest())
        return true

  if filePath[^1] != '/':
    filePath.add("/")
    filePath.add(reqPath[state .. ^1])
  else:
    filePath.add(reqPath[state .. ^1])

  if filePath[^1] != '/':
    if existsDir(filePath):
      let host = getHeader(req, "Host")

      reqPath.add("/")

      await res.mofuw_send(redirectTo(
        "http://" / host / reqPath
      ))

      return true
    if fileExists(filePath):
      let f = openAsync(filePath, fmRead)
      file = await f.readAll()
      close(f)
    else:
      return false
  else:
    filePath.add("index.html")
    if fileExists(filePath):
      let f = openAsync(filePath, fmRead)
      file = await f.readAll()
      close(f)
    else:
      return false

  let (_, _, ext) = splitFile(filePath)

  shallowcopy(fileExt, ext[1 .. ^1])

  if ext == "":
    await res.mofuw_send(makeResp(
      HTTP200,
      "text/plain",
      file
    ))
  else:
    let mime = newMimetypes()

    await res.mofuw_send(makeResp(
      HTTP200,
      mime.getMimetype(ext[1 .. ^1], default = "application/octet-stream"),
      file
    ))

  return true