import strtabs
import randUtils

from cookies import parseCookies

const
  sessionName = "MOFUW_SESSION"

proc setCookie*(name, value: string,
                expires = "", maxAges = "",
                domain = "", path = "",
                secure = false, httpOnly = false):
                tuple[name, value, session: string] =

  var session = ""

  session.add(name)
  session.add("=")
  session.add(value)

  if domain != "":
    session.add("; Domain=")
    session.add(domain)

  if path != "":
    session.add("; Path=")
    session.add(path)

  if expires != "":
    session.add("; Expires=")
    session.add(expires)

  if secure:
    session.add("; Secure")

  if httpOnly:
    session.add("; HttpOnly")

  result = ("Set-Cookie", session, value)

proc setAuth*(name, value: string,
              expires = "", maxAges = "",
              domain = "", path = "",
              secure = false, httpOnly = true):
              tuple[name, value, session: string] =

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

proc genSessionString*(len: int = 32): string =
  result = randString(len)

proc getSession*(cookies: StringTableRef): string =
  if not cookies.hasKey(sessionName):
    return ""
  return cookies[sessionName]

proc genSessionCookie*(): tuple[name, value, session: string] =
  setAuth(sessionName, genSessionString())

when isMainModule:
  echo genSessionCookie()