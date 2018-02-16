import mofuw, os, mimetypes

proc reverse(s: var string) =
  for i in 0 .. s.high div 2:
    swap(s[i], s[s.high - i])

proc serveStatic*(req: ptr mofuwReq, res: ptr mofuwRes, rootPath: string): bool =
  var
    state = 0
    reqPath = getPath(req)
    fileName = ""
    fileExt = ""
    filePath = rootPath
    file: string

  #echo repr rootPath
  #echo repr filePath

  #for k, v in reqPath:
  #  if v == '/':
  #    state = k + 1
  #    break

  if filePath[^1] != '/':
    filePath.add("/")
    filePath.add(reqPath[state .. ^1])
  else:
    filePath.add(reqPath[state .. ^1])

  if filePath[^1] != '/':
    if existsDir(filePath):
      res.mofuw_send(redirectTo(
        filePath
      ))
      return true
    if fileExists(filePath):
      file = readFile(filePath)
    else:
      return false
  else:
    filePath.add("index.html")
    if fileExists(filePath):
      file = readFile(filePath)
    else:
      return false

  state = 0
  reverse(filePath)

  for k, v in filePath:
    case v
    of '/':
      fileName.add(filePath[state .. k-1])
      if fileName != "": reverse(fileName)
      break
    of '.':
      fileExt.add(filePath[0 .. k-1])
      reverse(fileExt)
      state = k + 1
    else:
      discard

  let
    mime = newMimetypes()

  res.mofuw_send(makeResp(
    HTTP200,
    mime.getMimetype(fileExt, default = "application/octet-stream"),
    file
  ))

  return true