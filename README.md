# mofuw [![Build Status](https://semaphoreci.com/api/v1/2vg/mofuw/branches/master/badge.svg)](https://semaphoreci.com/2vg/mofuw)

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![Maintainability](https://api.codeclimate.com/v1/badges/1602ec8a231cbaabf155/maintainability)](https://codeclimate.com/github/2vg/mofuw/maintainability)

> mofuw is **M**eccha hayai Asynchronous, Non-Blocking I/**O** no super **F**ast de **U**ltra minimal na **W**eb server on Nim.

> もふぅ ꒰ᐡ - ﻌ - ᐡ꒱ ♡ @2vg

## Warning
mofuw is now developping.

please be careful when using.

## Require
- nim (nim-devel)
- libuv (must installed ver 1.19.0)

## Usage
see [example](https://github.com/2vg/mofuw/blob/master/example)

you want to ask how to build ? B U I L D ? hahaha, is joke ?

mofuw is non need B U I L D.

install is need only `git clone`.

(sure, installed nim 0.17.3 and libuv 1.19)

```sh
git clone https://github.com/2vg/mofuw
```

you can use "import mofuw". this only.

minimal example is this 👇

```nim
import mofuw

mofuw.callback = proc(req: ptr mofuwReq, res: ptr mofuwRes) =
  if getPath(req) == "/":
    res.mofuw_send(makeResp(
      HTTP200,
      "text/plain",
      "Hello, World!"
    ))
  else:
    res.mofuw_send(notFound())

mofuwRUN() # default listening port: 8080
```

W O W, super E A S Y !!!!!! AMAYZING !!!!!!!

and...... hyper F A S T !!!!!!! YEAHHHHHHHHHHH.....

if you will using mofuw, you will be very surprised.

**Now support GET, POST, PATCH, PUT, DELETE, OPTIONS method only**

## Feature
- high-performance
- low used memory
- used backend is libuv, so Asynchronous I/O and Non-Blocking I/O
- my parser is implement like [picohttpparser](https://github.com/h2o/picohttpparser), so Zero-Copy, ultra fast parsing... yeah, fast may.
- Easy API, create Web Application, create an extended Web server
- multi-thread support, see app.nim

## Benchmark
see this benchmark result.

mofuw is more faster than [tokio-minihttp](https://github.com/tokio-rs/tokio-minihttp).

Update: changed routing match is using hash table so performance was down but a bit faster than tokio-mini yet.

### my server spec:

- OS: Arch Linux 4.13.8-1-ARCH
- CPU: Intel core 2Duo T7700 2.40GHz 3 Core
- MEM: 2GB

### tokio-minihttp

![tokio-minihttp.png](images/tokio-minihttp.png)

### mofuw

![mofuw.png](images/mofuw.png)

this is a slightly old benchmark result of [techempower](https://www.techempower.com/benchmarks/#section=data-r14&hw=ph&test=plaintext), but if can apply my benchmark result to this techempower's benchmark result, **👑mofuw can aim at 1st place👑**.

Update: this is latest techempower plaintext [result](https://www.techempower.com/benchmarks/previews/round15/#section=data-r15&hw=ph&test=plaintext)

unchanged, **👑mofuw can aim at 1st place👑**.

## Why fast ?
because using libuv, and using fast parser.

about my parser, check [mofuparser](https://github.com/2vg/mofuparser)

~~but, i want to use libev... because more faster than libuv...
this is developping now !~~

if i will made Asynchronous library, i will may replace libuv to libev or Selectors. (or make lib)

## ~~working change backend libuv to libev~~
~~yeah, found way multi-thread event loop so im develop change backend libuv to libev.
but probably, will not to change API usage~~

## Decided to continue developing the back end with libuv
- Why ?

A. because my understanding of asynchrony is not enough yet.

- No plans to change from libuv?

A. answer is **No**.

I will not develop it yet, but it's probably not a distant future.

## Todo
- [x] ~~header make proc(?)~~
- [x] ~~Cache (memory buffer ? collab with redis ?)~~ (maybe non need this.)
- [ ] File response (will soon complete)
- [x] routing (now support GET, POST, PATCH, PUT, DELETE, OPTIONS only, want to finish it early)
- [x] ~~multi-thread (this need ?)~~

## Special Thanks
- [jester](https://github.com/dom96/jester) (using jester's pattern and utils)
