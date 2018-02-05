import strtabs

from cookies import parseCookies

const
  sessionName = "MOFUW_SESSION"

proc setCookie*(name, value: string,
                expires = "", maxAges = "",
                domain = "", path = "",
                secure = false, httpOnly = false): string =

  result = ""
  result.add("Set-Cookie: ")
  result.add(key)
  result.add("=")
  result.add(value)

  if domain != "":
    result.add("; Domain=")
    result.add(domain)

  if path != "":
    result.add("; Path=")
    result.add(path)

  if expires != "":
    result.add("; Expires=")
    result.add(expires)

  if secure:
    result.add("; Secure")

  if httpOnly:
    result.add("; HttpOnly")

proc setAuth*(name, value: string,
              expires = "", maxAges = "",
              domain = "", path = "",
              secure = false, httpOnly = true): string =

  result = setCookie(
    name,
    value,
    expires,
    maxAges,
    domain,
    path,
    secure,
    httpOnly
  )

proc genSession*(): string =
  result = ""

proc getSession*(cookies: StringTableRef): string =
  if not cookies.hasKey(sessionName):
    return ""
  return cookies[sessionName]