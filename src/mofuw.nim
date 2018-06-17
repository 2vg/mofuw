import
  net,
  hashes,
  macros,
  osproc,
  tables,
  strtabs,
  strutils,
  threadpool,
  asyncdispatch2,
  nativesockets

from httpcore import HttpHeaders

when defined(windows):
  from winlean import TCP_NODELAY
else:
  from posix import TCP_NODELAY, EAGAIN, EWOULDBLOCK

when defined(linux):
  from posix import Pid
  const TCP_FASTOPEN = 23.cint

from os import osLastError

import
  mofuparser,
  mofuhttputils,
  mofuw/jesterPatterns,
  mofuw/jesterUtils

export
  strtabs,
  mofuhttputils,
  asyncdispatch2,
  jesterPatterns

type
  mofuwReq* = object
    mhr: MPHTTPReq
    buf*: string
    bodyStart: int
    bParams, params*: StringTableRef
    # this is for big request
    # TODO
    tmp*: cstring

  mofuwRes* = object
    fd: AsyncFD

  Callback = proc(req: mofuwReq, res: mofuwRes): Future[void]

const
  kByte = 1024
  mByte = 1024 * kByte

  defaultBufferSize = 8 * kByte
  defaultMaxBodySize {.intdefine.} = 10 * mByte
  bufSize {.intdefine.} = 512

var
  cacheTables {.threadvar.}: TableRef[string, string]
  callback    {.threadvar.}: Callback
  maxBodySize {.threadvar.}: int
  bufferSize  {.threadvar, deprecated.}: int

proc countCPUs(): int =
  when defined(linux):
    const
      schedh = "#define _GNU_SOURCE\n#include <sched.h>"
    type CpuSet {.importc: "cpu_set_t", header: schedh.} = object
      when defined(linux) and defined(amd64):
        abi: array[1024 div (8 * sizeof(culong)), culong]
    var set: CpuSet
    proc sched_getAffinity(pid: Pid, cpusetsize: int, mask: var CpuSet): cint {.
      importc: "sched_getaffinity", header: schedh.}
    proc cpusetCount(s: var CpuSet): int {. importc: "CPU_COUNT", header: schedh.}
    if sched_getAffinity(0, sizeof(CpuSet), set) == 0.cint:
      return cpusetCount(set)
    else:
      return countProcessors()
  else:
    return countProcessors()

proc defaultBacklog(): int =
  when defined(linux):
    proc fscanf(c: File, frmt: cstring): cint
      {.varargs, importc, header: "<stdio.h>".}

    var
      backlog: int = SOMAXCONN
      f: File
      tmp: int

    if f.open("/proc/sys/net/core/somaxconn"): # See `man 2 listen`.
      if fscanf(f, "%d", tmp.addr) == cint(1):
        backlog = tmp
      f.close
    return backlog
  else:
    return SOMAXCONN

proc newServerSocket(): SocketHandle =
  let server = newSocket()

  server.setSockOpt(OptReuseAddr, true)

  server.setSockOpt(OptReusePort, true)

  server.getFD().setSockOptInt(cint(IPPROTO_TCP), TCP_NODELAY, 1)

  when defined(linux):
    server.getFD().setSockOptInt(cint(IPPROTO_TCP), TCP_FASTOPEN, 256)

  server.getFd.setBlocking(false)

  return server.getFd()

proc updateTime(args: pointer = nil) =
  updateServerTime()

proc getMethod*(req: mofuwReq): string {.inline.} =
  result = getMethod(req.mhr)

proc getPath*(req: mofuwReq): string {.inline.} =
  result = getPath(req.mhr)

proc getCookie*(req: mofuwReq): string {.inline.} =
  result = getHeader(req.mhr, "Cookie")

proc getHeader*(req: mofuwReq, name: string): string {.inline.} =
  result = getHeader(req.mhr, name)

proc toHttpHeaders*(req: mofuwReq): HttpHeaders {.inline.} =
  result = req.mhr.toHttpHeaders()

proc bodyParse*(req: mofuwReq): StringTableRef =
  req.bodyParse

proc body*(req: var mofuwReq, key: string = nil): string =
  if key.isNil: return $req.buf[req.bodyStart .. ^1]
  if req.bParams.isNil: req.bParams = req.body.bodyParse
  req.bParams.getOrDefault(key)

proc handler(server: StreamServer,
             client: StreamTransport): Future[void] {.gcsafe.} =

  discard

proc newMofuwServer(address: string = "0.0.0.0",
                    port: int = 8080,
                    backlog = defaultBacklog()): StreamServer =
  discard
  let host = initTAddress(address & ":" & $port)
  let serverSocket = newServerSocket().AsyncFD

  return createStreamServer(
    host = host,
    cbproc = handler,
    sock =  serverSocket,
    backlog = backlog
  )