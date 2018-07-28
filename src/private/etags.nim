from os import FileInfo, getFileInfo
from times import toUnix
import strtabs
import std/sha1

const 
    etagLen* : int = 16
    etagEnabled* : bool = true

var 
    etags {.threadvar.} : StringTableRef

proc clearEtags* () {.inline thread.} = 
  etags = {:}.newStringTable

proc getEtag* (filePath:string) :string {.inline thread.} = 
  if etags.isNil : clearEtags()
  return if etags.hasKey(filePath) : etags[filePath] else : ""

proc initEtags() {.inline thread.} = 
  etags = {:}.newStringTable

# warning! nocheck file exists 
proc generateEtag* (filePath:string) :string {.inline thread.} = 
  let fi:FileInfo = filePath.getFileInfo()
  let hash = $ secureHash( $(fi.id.file) & $(fi.lastWriteTime.toUnix) & "s a l t")
  return if hash.len < etagLen : hash else : hash[0..<etagLen]

# warning! nocheck file exists 
proc isModifiedEtagWithUpdate* (filePath:string, reqEtag:string) :bool {.inline thread.} =
  if not etagEnabled : return true
  if etags.isNil : clearEtags()
  
  if etags.hasKey(filePath) :
    let etag = generateEtag(filePath)
    if reqEtag != etag : 
      etags[filePath] = etag
    else : 
      return false
  else : 
    etags[filePath] = generateEtag(filePath)
  
  return true

initEtags()

# test
when isMainModule :

  let path = "/Users/bazi/etagtest"
  var quit = false
  var etag = ""
  while not quit :
    echo "anykey push refresh etag . quit [q]"
    let input = readLine(stdin)
    if input == "q" : quit = true
    
    echo "path: ",path
    echo "isModifiedEtag : " , isModifiedEtagWithUpdate(path, etag)
    echo etags
    etag = etags[path]
