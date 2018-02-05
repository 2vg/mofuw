import times, httpcore

const
  HTTP100* = "HTTP/1.1 100 Continue" & "\r\L"
  HTTP101* = "HTTP/1.1 101 Switching Protocols" & "\r\L"
  HTTP200* = "HTTP/1.1 200 OK" & "\r\L"
  HTTP201* = "HTTP/1.1 201 Created" & "\r\L"
  HTTP202* = "HTTP/1.1 202 Accepted" & "\r\L"
  HTTP203* = "HTTP/1.1 203 Non-Authoritative Information" & "\r\L"
  HTTP204* = "HTTP/1.1 204 No Content" & "\r\L"
  HTTP205* = "HTTP/1.1 205 Reset Content" & "\r\L"
  HTTP206* = "HTTP/1.1 206 Partial Content" & "\r\L"
  HTTP207* = "HTTP/1.1 207 Multi-Status" & "\r\L"
  HTTP208* = "HTTP/1.1 208 Already Reported" & "\r\L"
  HTTP226* = "HTTP/1.1 226 IM Used" & "\r\L"
  HTTP300* = "HTTP/1.1 300 Multiple Choices" & "\r\L"
  HTTP301* = "HTTP/1.1 301 Moved Permanently" & "\r\L"
  HTTP302* = "HTTP/1.1 302 Found" & "\r\L"
  HTTP303* = "HTTP/1.1 303 See Other" & "\r\L"
  HTTP304* = "HTTP/1.1 304 Not Modified" & "\r\L"
  HTTP305* = "HTTP/1.1 305 Use Proxy" & "\r\L"
  HTTP307* = "HTTP/1.1 307 Temporary Redirect" & "\r\L"
  HTTP308* = "HTTP/1.1 308 Permanent Redirect" & "\r\L"
  HTTP400* = "HTTP/1.1 400 Bad Request" & "\r\L"
  HTTP401* = "HTTP/1.1 401 Unauthorized" & "\r\L"
  HTTP402* = "HTTP/1.1 402 Payment Required" & "\r\L"
  HTTP403* = "HTTP/1.1 403 Forbidden" & "\r\L"
  HTTP404* = "HTTP/1.1 404 Not Found" & "\r\L"
  HTTP405* = "HTTP/1.1 405 Method Not Allowed" & "\r\L"
  HTTP406* = "HTTP/1.1 406 Not Acceptable" & "\r\L"
  HTTP407* = "HTTP/1.1 407 Proxy Authentication Required" & "\r\L"
  HTTP408* = "HTTP/1.1 408 Request Timeout" & "\r\L"
  HTTP409* = "HTTP/1.1 409 Conflict" & "\r\L"
  HTTP410* = "HTTP/1.1 410 Gone" & "\r\L"
  HTTP411* = "HTTP/1.1 411 Length Required" & "\r\L"
  HTTP412* = "HTTP/1.1 412 Precondition Failed" & "\r\L"
  HTTP413* = "HTTP/1.1 413 Request Entity Too Large" & "\r\L"
  HTTP414* = "HTTP/1.1 414 Request-URI Too Long" & "\r\L"
  HTTP415* = "HTTP/1.1 415 Unsupported Media Type" & "\r\L"
  HTTP416* = "HTTP/1.1 416 Requested Range Not Satisfiable" & "\r\L"
  HTTP417* = "HTTP/1.1 417 Expectation Failed" & "\r\L"
  HTTP418* = "HTTP/1.1 418 I'm a teapot" & "\r\L"
  HTTP421* = "HTTP/1.1 421 Misdirected Request" & "\r\L"
  HTTP422* = "HTTP/1.1 422 Unprocessable Entity" & "\r\L"
  HTTP423* = "HTTP/1.1 423 Locked" & "\r\L"
  HTTP424* = "HTTP/1.1 424 Failed Dependency" & "\r\L"
  HTTP426* = "HTTP/1.1 426 Upgrade Required" & "\r\L"
  HTTP428* = "HTTP/1.1 428 Precondition Required" & "\r\L"
  HTTP429* = "HTTP/1.1 429 Too Many Requests" & "\r\L"
  HTTP431* = "HTTP/1.1 431 Request Header Fields Too Large" & "\r\L"
  HTTP451* = "HTTP/1.1 451 Unavailable For Legal Reasons" & "\r\L"
  HTTP500* = "HTTP/1.1 500 Internal Server Error" & "\r\L"
  HTTP501* = "HTTP/1.1 501 Not Implemented" & "\r\L"
  HTTP502* = "HTTP/1.1 502 Bad Gateway" & "\r\L"
  HTTP503* = "HTTP/1.1 503 Service Unavailable" & "\r\L"
  HTTP504* = "HTTP/1.1 504 Gateway Timeout" & "\r\L"
  HTTP505* = "HTTP/1.1 505 HTTP Version Not Supported" & "\r\L"
  HTTP506* = "HTTP/1.1 506 Variant Also Negotiates" & "\r\L"
  HTTP507* = "HTTP/1.1 507 Insufficient Storage" & "\r\L"
  HTTP508* = "HTTP/1.1 508 Loop Detected" & "\r\L"
  HTTP509* = "HTTP/1.1 509 Bandwidth Limit Exceeded" & "\r\L"
  HTTP510* = "HTTP/1.1 510 Not Extended" & "\r\L"

const
  serverName = "mofuw 0.0.1"

var
  serverTime {.threadvar.}: string

proc getServerTime*(): string =
  result = format(getTime().inZone(utc()), "ddd, dd MMM yyyy hh:mm:ss 'GMT'")

proc getGlobalServerTime*(): string =
  result = serverTime

proc updateServerTime*() =
  serverTime = getServerTime()

proc makeRespNoBody*(statusLine: string): string {.inline.}=
  result = statusLine
  result.add("Server: ")
  result.add(serverName)
  result.add("\r\LDate: ")
  result.add(serverTime)
  result.add("\r\L")
  #result.add("\r\LConnection: keep-alive\r\L")

proc makeResp*(statusLine: string, mime: string, body: string, charset: string = "UTF-8"): string {.inline.}=
  result = makeRespNoBody(statusLine)
  result.add("Content-Type: ")
  result.add(mime)
  result.add("; charset=")
  result.add(charset)
  result.add("\r\LContent-Length: ")
  result.add(body.len)
  result.add("\r\L\r\L")
  result.add(body)

proc makeResp*(statusLine: string, headers: HttpHeaders, body: string): string {.inline.} =
  result = ""
  result.add(statusLine)

  for k, v in headers:
    if k == "Content-Length":
      result.add("Content-Length: ")
      result.add($(body.len))
      result.add("\r\L")
      continue
    result.add(k)
    result.add(": ")
    result.add(v)
    result.add("\r\L")

  result.add("\r\L")
  result.add(body)

proc addHeader*(body: string, headers: openArray[tuple[name: string, value: string]]): string {.inline.}=
  result = ""
  result.add(body)
  for v in headers:
    result.add(v.name)
    result.add(": ")
    result.add(v.value)
    result.add("\r\L")

proc addBody*(str: string, mime: string, body: string, charset: string = "UTF-8"): string {.inline.} =
  result = ""
  result.add(str)
  result.add("Content-Type: ")
  result.add(mime)
  result.add("; charset=")
  result.add(charset)
  result.add("\r\LContent-Length: ")
  result.add(body.len)
  result.add("\r\L\r\L")
  result.add(body)

proc redirectTo*(URL: string): string {.inline.}=
  result = addHeader(makeRespNoBody(HTTP301), @[("Location", URL)])
  result.add("\r\L")

proc badRequest*(): string {.inline.}=
  result = makeResp(
    HTTP400,
    "text/html",
    "<html><head><title>400 Bad Request</title></head><body style=\"text-align: center;\"><h1>400 Bad Request</h1><hr/><p>Mofuw 0.0.1</p></body></html>"
  )

proc notFound*(): string {.inline.}=
  result = makeResp(
    HTTP404,
    "text/html",
    "<html><head><title>404 Not Found</title></head><body style=\"text-align: center;\"><h1>404 Not Found</h1><hr/><p>Mofuw 0.0.1</p></body></html>"
  )

proc bodyTooLarge*(): string {.inline.}=
  result = makeResp(
    HTTP413,
    "text/html",
    "<html><head><title>413 Request Entity Too Large</title></head><body style=\"text-align: center;\"><h1>413 Request Entity Too Large</h1><hr/><p>Mofuw 0.0.1</p></body></html>"
  )