when defined ssl:
  import ctx
  import os, net, openssl, asyncdispatch
  export openssl
  export net.SslCVerifyMode

  when not declared(SSL_set_SSL_CTX):
    proc SSL_set_SSL_CTX*(ssl: SslPtr, ctx: SslCtx): SslCtx
      {.cdecl, dynlib: DLLSSLName, importc.}

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
    ctx.sslHandle = SSLNew(ctx.sslCtx)
    discard SSL_set_fd(ctx.sslHandle, ctx.fd.SocketHandle)
    discard SSL_accept(ctx.sslHandle)

  proc asyncSSLRecv*(ctx: MofuwCtx, buf: ptr char, bufLen: int): Future[int] =
    var retFuture = newFuture[int]("asyncSSLRecv")
    proc cb(fd: AsyncFD): bool =
      result = true
      let rcv = SSL_read(ctx.sslHandle, buf, bufLen.cint)
      if rcv <= 0:
        retFuture.complete(0)
      else:
        retFuture.complete(rcv)
    addRead(ctx.fd, cb)
    return retFuture

  proc asyncSSLSend*(ctx: MofuwCtx, buf: ptr char, bufLen: int): Future[int] =
    var retFuture = newFuture[int]("asyncSSLSend")
    proc cb(fd: AsyncFD): bool =
      result = true
      let rcv = SSL_write(ctx.sslHandle, buf, bufLen.cint)
      if rcv <= 0:
        retFuture.complete(0)
      else:
        retFuture.complete(rcv)
    addWrite(ctx.fd, cb)
    return retFuture

  proc addCertAndKey*(ctx: ServeCtx, cert, key: string, serverName = "", verify = false) =
    let ctx =
      if verify: newSSLContext(cert, key, CVerifyPeer)
      else: newSSLContext(cert, key)

    if ctx.sslCtxTbl.hasKey(serverName):
      raise newException(Exception, "already have callback.")

    ctx.sslCtxTbl[serverName] = ctx

    if not ctx.sslCtxTbl.hasKey(""): ctx.sslCtxTbl[""] = ctx