import os

proc reverse(s: var string) =
  for i in 0 .. s.high div 2:
    swap(s[i], s[s.high - i])

proc fileRead*(path: string): string =
  var
    f: File

  if open(f, path, FileMode.fmRead):
    try:
      let read = readAll(f)
      return read
    except:
      return ""
    finally:
        close(f)
  else:
    return ""

proc serveStatic*(reqPath, rootPath: string) =
  var
    state = 0
    fileName = ""
    fileExt = ""
    filePath: string

  shallowcopy(filePath, rootPath)

  #echo repr rootPath
  #echo repr filePath

  for k, v in reqPath:
    if v == '/':
      state = k + 1
      break

  if filePath[^1] != '/':
    filePath.add("/")
    filePath.add(reqPath[state .. ^1])
  else:
    filePath.add(reqPath[state .. ^1])

  if filePath[^1] != '/':
    if existsDir(filePath):
      echo "redirect"
      return
    if fileExists(filePath):
      let r = readFile(filePath)
      echo r
    else:
      echo "not found"
  else:
    filePath.add("index.html")
    if fileExists(filePath):
      let r = readFile(filePath)
      echo r
    else:
      echo "not found"

  echo repr rootPath
  echo repr filePath

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

var
  r = "./"
  t = "localhost:8080/"

t.serveStatic(r)