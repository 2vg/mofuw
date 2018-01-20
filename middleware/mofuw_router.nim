import mofuw
import lib/httputils
import strutils

type
  router = ref object
    GET: seq[router_t]
    POST: seq[router_t]
    PUT: seq[router_t]
    DELETE: seq[router_t]
    PATCH: seq[router_t]
    OPTIONS: seq[router_t]

  router_t = object
    path: string
    cb: proc(req: ptr mofuwReq, res: ptr mofuwRes)

proc newMofuwRouter*(): router =
  result = router(
    GET: @[],
    POST: @[],
    PUT: @[],
    DELETE: @[],
    PATCH: @[],
    OPTIONS: @[]
  )

proc mofuwGET*(r: router, path: string, cb: proc(req: ptr mofuwReq, res: ptr mofuwRes)) =
  r.GET.add(router_t(path: path, cb: cb))

proc mofuwPOST*(r: router, path: string, cb: proc(req: ptr mofuwReq, res: ptr mofuwRes)) =
  r.POST.add(router_t(path: path, cb: cb))

proc mofuwPUT*(r: router, path: string, cb: proc(req: ptr mofuwReq, res: ptr mofuwRes)) =
  r.PUT.add(router_t(path: path, cb: cb))
  
proc mofuwDELETE*(r: router, path: string, cb: proc(req: ptr mofuwReq, res: ptr mofuwRes)) =
  r.DELETE.add(router_t(path: path, cb: cb))

proc mofuwOPTIONS*(r: router, path: string, cb: proc(req: ptr mofuwReq, res: ptr mofuwRes)) =
  r.OPTIONS.add(router_t(path: path, cb: cb))

proc mofuwRouting*(r: router, request: ptr mofuwReq, response: ptr mofuwRes) {.inline.}=
  case getMethod(request)
  of "GET":
    if r.GET.len == 0:
      notFound(response)
    else:
      block searchRoute:
        for value in r.GET:
          if getPath(request) == value.path:
            value.cb(request, response)
            break searchRoute
        notFound(response)
  of "POST":
    if r.POST.len == 0:
      notFound(response)
    else:
      block searchRoute:
        for value in r.POST:
          if getPath(request) == value.path:
            for v in request.reqHeader:
              if v.namelen == 0: break

              if not(($(v.name))[0 .. v.namelen] == "Content-Length"):
                continue
              else:
                request.reqBodyLen = parseInt(($(v.value))[0 .. v.valuelen])
                request.reqBody = ($(request.reqBody))[0 .. request.reqBodyLen - 1]
                value.cb(request, response)
                break searchRoute
              response.mofuw_send(badRequest())
        notFound(response)
  of "PUT":
    if r.PUT.len == 0:
      notFound(response)
    else:
      block searchRoute:
        for value in r.PUT:
          if getPath(request) == value.path:
            for v in request.reqHeader:
              if v.namelen == 0: break

              if not(($(v.name))[0 .. v.namelen] == "Content-Length"):
                continue
              else:
                request.reqBodyLen = parseInt(($(v.value))[0 .. v.valuelen])
                request.reqBody = ($(request.reqBody))[0 .. request.reqBodyLen - 1]
                value.cb(request, response)
                break searchRoute
              response.mofuw_send(badRequest())
        notFound(response)
  of "DELETE":
    if r.DELETE.len == 0:
      notFound(response)
    else:
      block searchRoute:
        for value in r.DELETE:
          if getPath(request) == value.path:
            for v in request.reqHeader:
              if v.namelen == 0: break

              if not(($(v.name))[0 .. v.namelen] == "Content-Length"):
                continue
              else:
                request.reqBodyLen = parseInt(($(v.value))[0 .. v.valuelen])
                request.reqBody = ($(request.reqBody))[0 .. request.reqBodyLen - 1]
                value.cb(request, response)
                break searchRoute
              response.mofuw_send(badRequest())
        notFound(response)
  of "PATCH":
    if r.PATCH.len == 0:
      notFound(response)
    else:
      block searchRoute:
        for value in r.PATCH:
          if getPath(request) == value.path:
            for v in request.reqHeader:
              if v.namelen == 0: break

              if not(($(v.name))[0 .. v.namelen] == "Content-Length"):
                continue
              else:
                request.reqBodyLen = parseInt(($(v.value))[0 .. v.valuelen])
                request.reqBody = ($(request.reqBody))[0 .. request.reqBodyLen - 1]
                value.cb(request, response)
                break searchRoute
              response.mofuw_send(badRequest())
        notFound(response)
  of "OPTIONS":
    if r.OPTIONS.len == 0:
      notFound(response)
    else:
      block searchRoute:
        for value in r.OPTIONS:
          if getPath(request) == value.path:
            value.cb(request, response)
            break searchRoute
        notFound(response)
  else:
    notFound(response)