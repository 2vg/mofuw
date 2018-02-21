import mofuw, os, mimetypes, uri, asyncfile

proc reverse(s: var string) =
  for i in 0 .. s.high div 2:
    swap(s[i], s[s.high - i])

proc serveStatic*(req: mofuwReq, res: mofuwRes, rootPath: string): Future[bool] {.async.} =
  var
    state = 0
    reqPath = getPath(req)
    fileName = ""
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
      var host = ""
      for v in req.reqHeader:
        if v.namelen == 0: break
        if ($(v.name))[0 .. v.namelen] == "Host":
          host.add(($(v.value))[0 .. v.valuelen])

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

  state = 0

  for i in countdown(filePath.len - 1, 0):
    case filePath[i]
    of '/':
      fileName.add(filePath[i + 1 .. state])
      if fileName != "": reverse(fileName)
      break
    of '.':
      fileExt.add(filePath[i+1 .. ^1])
      reverse(fileExt)
      state = i - 1
    else:
      discard

  let
    mime = newMimetypes()

  await res.mofuw_send(makeResp(
    HTTP200,
    mime.getMimetype(fileExt, default = "application/octet-stream"),
    file
  ))

  return true