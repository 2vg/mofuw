# mofuwAuth

> implemention Session for like login system.

### warning

if your gcc is very old, maybe cant compile this module.

### feature

- gen random secure string for session key.
- gen like cookie for session.
- get session key from request header.

### example
```nim
import mofuwAuth

echo genSessionCookie()

# value of MOFUW_SESSION is generated with a random 32 length value each time calling genSessionCookie.
# 
# (name: "Set-Cookie",
#  value: "MOFUW_SESSION=lLLdcmi7KmwGxcR1qfyLRuu8XxKiAUtZ; HttpOnly",
#  session: "lLLdcmi7KmwGxcR1qfyLRuu8XxKiAUtZ")

# return variable is tuple[name, value, session: string]
# so, you can write this:
# 
# let (x, y, z) = genSessionCookie()
# echo x <- "Set-Cookie"
# echo y <- "MOFUW_SESSION=lLLdcmi7KmwGxcR1qfyLRuu8XxKiAUtZ; HttpOnly"
# echo z <- "lLLdcmi7KmwGxcR1qfyLRuu8XxKiAUtZ"
```

### like login system

implementing something like a login system is easy.

(as long as you understand cookies and sessions)

save the user information used for login in a file or DB and link it with the generated session key.

after linking, add the session key to the response header.

On the server side, by checking the client's header and obtaining the session key from the cookie, you can determine if there is a session key, check if it is a saved session key.

i will proceed with development to make it easier to construct a login system with DB as the back end.