import ../mofuw

type
  router = ref object
    GET: seq[router_t]
    POST: seq[router_t]

  router_t = object
    path: string
    cb: proc(req: ptr mofuwReq, res: ptr mofuwRes)

proc newMofuwRouter*(): router =
  result = router(
    GET: @[],
    POST: @[]
  )

proc mofuwGET*(r: router, path: string, cb: proc(req: ptr mofuwReq, res: ptr mofuwRes)) =
  r.GET.add(router_t(path: path, cb: cb))

proc mofuwPOST*(r: router, path: string, cb: proc(req: ptr mofuwReq, res: ptr mofuwRes)) =
  r.POST.add(router_t(path: path, cb: cb))

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
            value.cb(request, response)
            break searchRoute
        notFound(response)
  else:
    notFound(response)