type
  HttpCode* = int

const
  Http100* = HttpCode(100)
  Http101* = HttpCode(101)
  Http200* = HttpCode(200)
  Http201* = HttpCode(201)
  Http202* = HttpCode(202)
  Http203* = HttpCode(203)
  Http204* = HttpCode(204)
  Http205* = HttpCode(205)
  Http206* = HttpCode(206)
  Http300* = HttpCode(300)
  Http301* = HttpCode(301)
  Http302* = HttpCode(302)
  Http303* = HttpCode(303)
  Http304* = HttpCode(304)
  Http305* = HttpCode(305)
  Http307* = HttpCode(307)
  Http400* = HttpCode(400)
  Http401* = HttpCode(401)
  Http403* = HttpCode(403)
  Http404* = HttpCode(404)
  Http405* = HttpCode(405)
  Http406* = HttpCode(406)
  Http407* = HttpCode(407)
  Http408* = HttpCode(408)
  Http409* = HttpCode(409)
  Http410* = HttpCode(410)
  Http411* = HttpCode(411)
  Http412* = HttpCode(412)
  Http413* = HttpCode(413)
  Http414* = HttpCode(414)
  Http415* = HttpCode(415)
  Http416* = HttpCode(416)
  Http417* = HttpCode(417)
  Http418* = HttpCode(418)
  Http421* = HttpCode(421)
  Http422* = HttpCode(422)
  Http426* = HttpCode(426)
  Http428* = HttpCode(428)
  Http429* = HttpCode(429)
  Http431* = HttpCode(431)
  Http451* = HttpCode(451)
  Http500* = HttpCode(500)
  Http501* = HttpCode(501)
  Http502* = HttpCode(502)
  Http503* = HttpCode(503)
  Http504* = HttpCode(504)
  Http505* = HttpCode(505)

  Http11_100* = HttpCode(1100)
  Http11_101* = HttpCode(1101)
  Http11_200* = HttpCode(1200)
  Http11_201* = HttpCode(1201)
  Http11_202* = HttpCode(1202)
  Http11_203* = HttpCode(1203)
  Http11_204* = HttpCode(1204)
  Http11_205* = HttpCode(1205)
  Http11_206* = HttpCode(1206)
  Http11_300* = HttpCode(1300)
  Http11_301* = HttpCode(1301)
  Http11_302* = HttpCode(1302)
  Http11_303* = HttpCode(1303)
  Http11_304* = HttpCode(1304)
  Http11_305* = HttpCode(1305)
  Http11_307* = HttpCode(1307)
  Http11_400* = HttpCode(1400)
  Http11_401* = HttpCode(1401)
  Http11_403* = HttpCode(1403)
  Http11_404* = HttpCode(1404)
  Http11_405* = HttpCode(1405)
  Http11_406* = HttpCode(1406)
  Http11_407* = HttpCode(1407)
  Http11_408* = HttpCode(1408)
  Http11_409* = HttpCode(1409)
  Http11_410* = HttpCode(1410)
  Http11_411* = HttpCode(1411)
  Http11_412* = HttpCode(1412)
  Http11_413* = HttpCode(1413)
  Http11_414* = HttpCode(1414)
  Http11_415* = HttpCode(1415)
  Http11_416* = HttpCode(1416)
  Http11_417* = HttpCode(1417)
  Http11_418* = HttpCode(1418)
  Http11_421* = HttpCode(1421)
  Http11_422* = HttpCode(1422)
  Http11_426* = HttpCode(1426)
  Http11_428* = HttpCode(1428)
  Http11_429* = HttpCode(1429)
  Http11_431* = HttpCode(1431)
  Http11_451* = HttpCode(1451)
  Http11_500* = HttpCode(1500)
  Http11_501* = HttpCode(1501)
  Http11_502* = HttpCode(1502)
  Http11_503* = HttpCode(1503)
  Http11_504* = HttpCode(1504)
  Http11_505* = HttpCode(1505)

proc `$$`*(code: HttpCode): string =
  case code.int
  of 100, 1100: "100 Continue"
  of 101, 1101: "101 Switching Protocols"
  of 200, 1200: "200 OK"
  of 201, 1201: "201 Created"
  of 202, 1202: "202 Accepted"
  of 203, 1203: "203 Non-Authoritative Information"
  of 204, 1204: "204 No Content"
  of 205, 1205: "205 Reset Content"
  of 206, 1206: "206 Partial Content"
  of 300, 1300: "300 Multiple Choices"
  of 301, 1301: "301 Moved Permanently"
  of 302, 1302: "302 Found"
  of 303, 1303: "303 See Other"
  of 304, 1304: "304 Not Modified"
  of 305, 1305: "305 Use Proxy"
  of 307, 1307: "307 Temporary Redirect"
  of 400, 1400: "400 Bad Request"
  of 401, 1401: "401 Unauthorized"
  of 403, 1403: "403 Forbidden"
  of 404, 1404: "404 Not Found"
  of 405, 1405: "405 Method Not Allowed"
  of 406, 1406: "406 Not Acceptable"
  of 407, 1407: "407 Proxy Authentication Required"
  of 408, 1408: "408 Request Timeout"
  of 409, 1409: "409 Conflict"
  of 410, 1410: "410 Gone"
  of 411, 1411: "411 Length Required"
  of 412, 1412: "412 Precondition Failed"
  of 413, 1413: "413 Request Entity Too Large"
  of 414, 1414: "414 Request-URI Too Long"
  of 415, 1415: "415 Unsupported Media Type"
  of 416, 1416: "416 Requested Range Not Satisfiable"
  of 417, 1417: "417 Expectation Failed"
  of 418, 1418: "418 I'm a teapot"
  of 421, 1421: "421 Misdirected Request"
  of 422, 1422: "422 Unprocessable Entity"
  of 426, 1426: "426 Upgrade Required"
  of 428, 1428: "428 Precondition Required"
  of 429, 1429: "429 Too Many Requests"
  of 431, 1431: "431 Request Header Fields Too Large"
  of 451, 1451: "451 Unavailable For Legal Reasons"
  of 500, 1500: "500 Internal Server Error"
  of 501, 1501: "501 Not Implemented"
  of 502, 1502: "502 Bad Gateway"
  of 503, 1503: "503 Service Unavailable"
  of 504, 1504: "504 Gateway Timeout"
  of 505, 1505: "505 HTTP Version Not Supported"
  else:   $(int(code))