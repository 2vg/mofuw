import strtabs, critbits, asyncdispatch
import mofuparser

when defined ssl:
  import os, net, openssl, nativesockets
  export openssl
  export net.SslCVerifyMode

  when not declared(SSL_set_SSL_CTX):
    proc SSL_set_SSL_CTX*(ssl: SslPtr, ctx: SslCtx): SslCtx
      {.cdecl, dynlib: DLLSSLName, importc.}

type
  MofuwHandler* = proc(ctx: MofuwCtx): Future[void] {.gcsafe.}

  VhostTable* = CritBitTree[MofuwHandler]

  ServeCtx* = ref object
    servername*: string
    port*: int
    readBufferSize*, writeBufferSize*, maxBodySize*: int
    timeout*: int
    poolsize*: int
    handler*, hookrequest*, hookresponse*: MofuwHandler
    vhostTbl*: VhostTable
    when defined ssl:
      sslCtxTbl*: CritBitTree[SslCtx]

  MofuwCtx* = ref object
    fd*: AsyncFD
    mhr*: MPHTTPReq
    mc*: MPChunk
    ip*: string
    buf*, resp*: string
    bufLen*, respLen*: int
    currentBufPos*: int
    bodyStart*: int
    maxBodySize*: int
    bodyParams*, uriParams*, uriQuerys*: StringTableRef
    vhostTbl*: VhostTable
    when defined ssl:
      isSSL*: bool
      sslCtx*: SslCtx
      sslHandle*: SslPtr

proc newServeCtx*(servername = "mofuw", port: int,
                  handler: MofuwHandler = nil,
                  readBufferSize, writeBufferSize = 4096,
                  maxBodySize = 1024 * 1024 * 5,
                  timeout = 3 * 1000,
                  poolsize = 128): ServeCtx =
  result = ServeCtx(
    servername: servername,
    port: port,
    handler: handler,
    readBufferSize: readBufferSize,
    writeBufferSize: writeBufferSize,
    maxBodySize: maxBodySize,
    timeout: timeout,
    poolsize: poolsize
  )

proc newMofuwCtx*(readSize: int, writeSize: int): MofuwCtx =
  result = MofuwCtx(
    buf: newString(readSize),
    resp: newString(writeSize),
    bufLen: 0,
    respLen: 0,
    currentBufPos: 0,
    mhr: MPHTTPReq()
  )

when defined ssl:
  # https://mozilla.github.io/server-side-tls/ssl-config-generator/?hsts=no
  const strongCipher = 
    "ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:" &
    "ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:" &
    "ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256"

  SSL_library_init()

  # ##
  # From net module
  # ##
  proc loadCertificates(ctx: SSL_CTX, certFile, keyFile: string) =
    if certFile != "" and (not existsFile(certFile)):
      raise newException(system.IOError, "Certificate file could not be found: " & certFile)
    if keyFile != "" and (not existsFile(keyFile)):
      raise newException(system.IOError, "Key file could not be found: " & keyFile)

    if certFile != "":
      var ret = SSLCTXUseCertificateChainFile(ctx, certFile)
      if ret != 1:
        raiseSSLError()

    if keyFile != "":
      if SSL_CTX_use_PrivateKey_file(ctx, keyFile,
                                     SSL_FILETYPE_PEM) != 1:
        raiseSSLError()

      if SSL_CTX_check_private_key(ctx) != 1:
        raiseSSLError("Verification of private key file failed.")

  # ##
  # From net module
  # Edited by @2vg
  # ##
  proc newSSLContext(cert, key: string, mode = CVerifyNone): SslCtx =
    var newCtx: SslCtx
    newCTX = SSL_CTX_new(TLS_server_method())

    if newCTX.SSLCTXSetCipherList(strongCipher) != 1:
      raiseSSLError()
    case mode
    of CVerifyPeer:
      newCTX.SSLCTXSetVerify(SSLVerifyPeer, nil)
    of CVerifyNone:
      newCTX.SSLCTXSetVerify(SSLVerifyNone, nil)
    if newCTX == nil:
      raiseSSLError()

    discard newCTX.SSLCTXSetMode(SSL_MODE_AUTO_RETRY)

    newCTX.loadCertificates(cert, key)

    return newCtx

  proc serverNameCallback(ssl: SslPtr, cb_id: int, arg: pointer): int {.cdecl.} =
    if ssl.isNil: return SSL_TLSEXT_ERR_NOACK
    let serverName = SSL_get_servername(ssl)
    let sslCtxTable = cast[ptr CritBitTree[SslCtx]](arg)[]
    if sslCtxTable.hasKey($serverName):
      let newCtx = sslCtxTable[$serverName]
      discard ssl.SSL_set_SSL_CTX(newCtx)
    return SSL_TLSEXT_ERR_OK

  # ##
  # normal fd to sslFD and accept
  # ##
  proc toSSLSocket*(serverctx: ServeCtx, ctx: MofuwCtx) =
    ctx.sslCtx = serverctx.sslCtxTbl[""]
    discard ctx.sslCtx.SSL_CTX_set_tlsext_servername_callback(serverNameCallback)
    discard ctx.sslCtx.SSL_CTX_set_tlsext_servername_arg(addr serverctx.sslCtxTbl)
    ctx.sslHandle = SSLNew(ctx.sslCtx)
    discard SSL_set_fd(ctx.sslHandle, ctx.fd.SocketHandle)
    discard SSL_accept(ctx.sslHandle)

  proc addCertAndKey*(serverctx: ServeCtx, cert, key: string, serverName = "", verify = false) =
    let ctx =
      if verify: newSSLContext(cert, key, CVerifyPeer)
      else: newSSLContext(cert, key)

    if serverctx.sslCtxTbl.hasKey(serverName):
      raise newException(Exception, "already have callback.")
      
    serverctx.sslCtxTbl[serverName] = ctx

    if not serverctx.sslCtxTbl.hasKey(""): serverctx.sslCtxTbl[""] = ctx