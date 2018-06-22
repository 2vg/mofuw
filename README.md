# mofuw 

[![Author: 2vg](https://img.shields.io/badge/mofuw-%C2%B0%CA%9A%20%C9%9E%C2%B0-green.svg)](https://github.com/2vg/mofuw)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

> **MO**re **F**ast **U**ltra **W**eb server.

> もふぅ ꒰ᐡ - ﻌ - ᐡ꒱ ♡ @2vg

> ~~mofuw is **M**eccha hayai Asynchronous I/**O** no super **F**ast de **U**ltra minimal na **W**eb server on Nim.~~

## Feature
- cross platform
- high-performance
- low used memory
- used backend is Nim's asyncdispatch, so all is Asynchronous I/O :)
- my parser is implement like [picohttpparser](https://github.com/h2o/picohttpparser), so Zero-Copy, ultra fast parsing... yeah, fast may.
- Easy API, create Web Application, create an extended Web server
- multi-thread event-loop.

## Build Status

#### Linux: [![Build Status](https://semaphoreci.com/api/v1/2vg/mofuw/branches/master/badge.svg)](https://semaphoreci.com/2vg/mofuw)

#### macOS: [![Build Status](https://travis-ci.org/2vg/mofuw.svg?branch=master)](https://travis-ci.org/2vg/mofuw)

#### Windows: [![Build status](https://ci.appveyor.com/api/projects/status/m6g40k0fd3m1w08t?svg=true)](https://ci.appveyor.com/project/2vg/mofuw)

## Why is Windows at the bottom of build status section ?
A. because Windows is shitty.

## Warning
mofuw is now developping.

please be careful when using.

## Require
- Nim >= 0.18.0
- mofuparser
- mofuhttputils

## Support Platforms
- Windows10 (tested on x64)
- Linux (tested on x64 ArchLinux)
- macOS

## awesome mofuw project
- [mofuw-api-boilerplate](https://github.com/OdaDaisuke/mofuw-api-boilerplate)

## Setup
before mofuw install, 

need Nim setup.

※ this is *Nim-devel*.

```shell
curl -L https://github.com/2vg/mofuw/raw/master/setup.sh | sh
```

after setup, need add /bin directory path to PATH.

## Usage
see [tests](https://github.com/2vg/mofuw/blob/master/tests)

you want to ask how to build ? B U I L D ? hahaha, is joke ?

mofuw is non need B U I L D.

install is need only `nimble install` or `git clone`.

of course, installed Nim >= 0.18.0.

see [setup](https://github.com/2vg/mofuw/blob/master/README.md#setup) section.

```sh
nimble install mofuw
```

or,

```
git clone https://github.com/2vg/mofuw
```

you can use "import mofuw". this only.

minimal example is this 👇

```nim
import mofuw

proc handler(req: mofuwReq, res: mofuwRes) {.async.} =
  routes:
    get "/":
      mofuwOK("Hello, World")

handler.mofuwRun() # default listening port: 8080
```

want serve static file ? OKOK, no problem.

can use mofuw's middleware, and can use `routesStatic` macro.

```nim
import
  mofuw,
  mofuw/middleware/staticServe/mofuwStaticServe

proc handler(req: mofuwReq, res: mofuwRes) {.async.} =
  # public directory serving.
  routesStatic "public":
    get "/api/hello":
      mofuwOK("hello")

handler.mofuwRun()
```

W O W, super E A S Y !!!!!! AMAZING !!!!!!!

and...... hyper F A S T !!!!!!! YEAHHHHHHHHHHH.....

if you will using mofuw, you will be very surprised.

if you want to see more example, see [tests](https://github.com/2vg/mofuw/tree/master/tests)

## Benchmark
Update(2018 - 06 - 11): mofuw is 24th on json tests :3 [techempowerRound16/JSON serialization](https://www.techempower.com/benchmarks/#section=data-r16&hw=ph&test=json)

Update(2018 - 04 - 07): mofuw is very fast :) [tbrand/which_is_the_fastest Issue#104](https://github.com/tbrand/which_is_the_fastest/issues/101#issuecomment-379293774)

## Todo
- [x] ~~header make proc(?)~~
- [x] Cache (memory buffer ? collab with redis ?)
- [ ] delete cache with timer;
- [x] ~~File response (will soon complete)~~
- [x] ~~routing (now support GET, POST, PATCH, PUT, DELETE, OPTIONS only, want to finish it early)~~
- [x] ~~multi-thread (this need ?)~~

## Contribute
**Pull requests are welcome !!!!!**

I am looking for someone who develops mofuw together.

Especially if there are people who can speed up and refactor it is the best!

## Special Thanks
- [jester](https://github.com/dom96/jester) (using jester's pattern and utils, and study macro)
- [kubo39](https://github.com/kubo39) (awesome... backlog proc, fix somaxconn, and more. super thx!)
- Thanks a lot dom96, and all Nimmers !