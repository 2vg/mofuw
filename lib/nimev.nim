when defined(windows):
  const libev* = "/path/libev.dll"
else:
  const libev* = "/usr/local/lib/libev.so"

const
  EV_MINPRI*        =      -2
  EV_MAXPRI*        =       2
  EV_VERSION_MAJOR* =       4
  EV_VERSION_MINOR* =      24

  EV_UNDEF*    =      0xFFFFFFFF # guaranteed to be invalid
  EV_NONE*     =            0x00 # no events
  EV_READ*     =            0x01 # ev_io detected read will not block
  EV_WRITE*    =            0x02 # ev_io detected write will not block
  EV_IOFDSET*  =            0x80 # internal use only
  EV_IO*       =         EV_READ # alias for type-detection
  EV_TIMER*    =      0x00000100 # timer timed out
  EV_TIMEOUT*  =        EV_TIMER # pre 4.0 API compatibility
  EV_PERIODIC* =      0x00000200 # periodic timer timed out
  EV_SIGNAL*   =      0x00000400 # signal was received
  EV_CHILD*    =      0x00000800 # child/pid had status change
  EV_STAT*     =      0x00001000 # stat data changed
  EV_IDLE*     =      0x00002000 # event loop is idling
  EV_PREPARE*  =      0x00004000 # event loop about to poll
  EV_CHECK*    =      0x00008000 # event loop finished poll
  EV_EMBED*    =      0x00010000 # embedded event loop needs sweep
  EV_FORK*     =      0x00020000 # event loop resumed in child
  EV_CLEANUP*  =      0x00040000 # event loop resumed in child
  EV_ASYNC*    =      0x00080000 # async intra-loop signal
  EV_CUSTOM*   =      0x01000000 # for use by user code
  EV_ERROR*    =      0x80000000 # sent when an error occurs

  # the default
  EVFLAG_AUTO*      = 0x00000000U # not quite a mask
  # flag bits
  EVFLAG_NOENV*     = 0x01000000U # do NOT consult environment
  EVFLAG_FORKCHECK* = 0x02000000U # check for a fork in each iteration
  # debugging/feature disable
  EVFLAG_NOINOTIFY* = 0x00100000U # do not attempt to use inotify
  EVFLAG_NOSIGFD*   = 0           # compatibility to pre-3.9
  EVFLAG_SIGNALFD*  = 0x00200000U # attempt to use signalfd
  EVFLAG_NOSIGMASK* = 0x00400000U # avoid modifying the signal mask

  # method bits to be ored together
  EVBACKEND_SELECT*  = 0x00000001U # available just about anywhere
  EVBACKEND_POLL*    = 0x00000002U # !win, !aix, broken on osx
  EVBACKEND_EPOLL*   = 0x00000004U # linux
  EVBACKEND_KQUEUE*  = 0x00000008U # bsd, broken on osx
  EVBACKEND_DEVPOLL* = 0x00000010U # solaris 8, NYI
  EVBACKEND_PORT*    = 0x00000020U # solaris 10
  EVBACKEND_ALL*     = 0x0000003FU # all known backends
  EVBACKEND_MASK*    = 0x0000FFFFU # all future backends

  # ev_run flags values
  EVRUN_NOWAIT* = 1 # do not block/wait
  EVRUN_ONCE*   = 2 # block *once* only

  # ev_break how values 
  EVBREAK_CANCEL* = 0 # undo unloop
  EVBREAK_ONE*    = 1 # unloop once
  EVBREAK_ALL*    = 2 # unloop all loops

type
  ev_loop_t* {.pure, final, importc: "struct ev_loop", header: "ev.h".} = ptr object
  ev_tstamp* = cdouble

  # can be used to add custom fields to all watchers, while losing binary compatibility
  ev_watcher_cb* = proc(loop: ptr ev_loop_t, w: ptr ev_watcher, revents: cint): void {.cdecl.}
  ev_watcher* {.pure, final, importc, header: "ev.h".} = object
    active* {.importc.}: cint
    pending* {.importc.}: cint
    priority* {.importc.}: cint
    data* {.importc.}: pointer
    cb*: ev_watcher_cb

  ev_watcher_list_cb* = proc(loop: ptr ev_loop_t, w: ptr ev_watcher_list, revents: cint): void {.cdecl.}
  ev_watcher_list* {.pure, final, importc, header: "ev.h".} = object
    active* {.importc.}: cint
    pending* {.importc.}: cint
    priority* {.importc.}: cint
    data* {.importc.}: pointer
    cb*: ev_watcher_list_cb
    next* {.importc.}: ptr ev_watcher_list

  ev_watcher_time_cb* = proc(loop: ptr ev_loop_t, w: ptr ev_watcher_time, revents: cint): void {.cdecl.}
  ev_watcher_time* {.pure, final, importc, header: "ev.h".} = object
    active* {.importc.}: cint
    pending* {.importc.}: cint
    priority* {.importc.}: cint
    data* {.importc.}: pointer
    cb*: ev_watcher_time_cb
    at* {.importc.}: ev_tstamp

  # invoked when fd is either EV_READable or EV_WRITEable
  # revent EV_READ, EV_WRITE
  ev_io_cb* = proc(loop: ptr ev_loop_t, w: ptr ev_io, revents: cint): void {.cdecl.}
  ev_io* {.pure, final, importc, header: "ev.h".} = object
    active* {.importc.}: cint
    pending* {.importc.}: cint
    priority* {.importc.}: cint
    data* {.importc.}: pointer
    cb*: ev_io_cb
    next* {.importc.}: ptr ev_watcher_list
    fd* {.importc.}: cint
    events* {.importc.}: cint

  # invoked after a specific time, repeatable (based on monotonic clock)
  # revent EV_TIMEOUT
  ev_timer_cb* = proc(loop: ptr ev_loop_t, w: ptr ev_timer, revents: cint) {.cdecl.}
  ev_timer* {.pure, final, importc, header: "ev.h".} = object
    active* {.importc.}: cint
    pending* {.importc.}: cint
    priority* {.importc.}: cint
    data* {.importc.}: pointer
    cb*: ev_timer_cb
    at* {.importc.}: ev_tstamp
    repeat* {.importc.}: ev_tstamp

  # invoked at some specific time, possibly repeating at regular intervals (based on UTC)
  # revent EV_PERIODIC
  ev_periodic_cb* = proc(loop: ptr ev_loop_t, w: ptr ev_periodic, revents: cint): void {.cdecl.}
  ev_periodic_rcb* = proc(w: ptr ev_periodic, now: ev_tstamp): ev_tstamp {.cdecl.}
  ev_periodic* {.pure, final, importc, header: "ev.h".} = object
    active* {.importc.}: cint
    pending* {.importc.}: cint
    priority* {.importc.}: cint
    data* {.importc.}: pointer
    cb*: ev_periodic_cb
    at* {.importc.}: ev_tstamp
    offset* {.importc.}: ev_tstamp
    interval* {.importc.}: ev_tstamp
    reschedule_cb*: ptr ev_periodic_rcb

  # invoked when the given signal has been received
  # revent EV_SIGNAL
  ev_signal_cb* = proc(loop: ptr ev_loop_t, w: ptr ev_signal, revents: cint): void {.cdecl.}
  ev_signal* {.pure, final, importc, header: "ev.h".} = object
    active* {.importc.}: cint
    pending* {.importc.}: cint
    priority* {.importc.}: cint
    data* {.importc.}: pointer
    cb*: ev_signal_cb
    next* {.importc.}: ptr ev_watcher_list
    signum* {.importc.}: cint

  # invoked when sigchld is received and waitpid indicates the given pid
  # revent EV_CHILD
  # does not support priorities
  ev_child_cb* = proc(loop: ptr ev_loop_t, w: ptr ev_child, revents: cint): void {.cdecl.}
  ev_child* {.pure, final, importc, header: "ev.h".} = object
    active* {.importc.}: cint
    pending* {.importc.}: cint
    priority* {.importc.}: cint
    data* {.importc.}: pointer
    cb*: ev_child_cb
    next* {.importc.}: ptr ev_watcher_list
    flags* {.importc.}: cint
    pid* {.importc.}: cint
    rpid* {.importc.}: cint
    rstatus* {.importc.}: cint

  # invoked each time the stat data changes for a given path
  # revent EV_STAT
  ev_statdata* {.importc: "struct stat", header: "sys/stat.h".} = object
  ev_stat_cb* = proc(loop: ptr ev_loop_t, w: ptr ev_stat, revents: cint): void {.cdecl.}
  ev_stat* {.pure, final, importc, header: "ev.h".} = object
    active* {.importc.}: cint
    pending* {.importc.}: cint
    priority* {.importc.}: cint
    data* {.importc.}: pointer
    cb*: ev_stat_cb
    next* {.importc.}: ptr ev_watcher_list
    timer* {.importc.}: ev_timer
    interval* {.importc.}: ev_tstamp
    path* {.importc.}: cstring
    prev* {.importc.}: ev_statdata
    attr* {.importc.}: ev_statdata
    wd* {.importc.}: cint

  # invoked when the nothing else needs to be done, keeps the process from blocking
  # revent EV_IDLE
  ev_idle_cb* = proc(loop: ptr ev_loop_t, w: ptr ev_idle, revents: cint): void {.cdecl.}
  ev_idle* {.pure, final, importc, header: "ev.h".} = object
    active* {.importc.}: cint
    pending* {.importc.}: cint
    priority* {.importc.}: cint
    data* {.importc.}: pointer
    cb*: ev_idle_cb

  # invoked for each run of the mainloop, just before the blocking call
  # you can still change events in any way you like
  # revent EV_PREPARE
  ev_prepare_cb* = proc(loop: ptr ev_loop_t, w: ptr ev_prepare, revents: cint): void {.cdecl.}
  ev_prepare* {.pure, final, importc, header: "ev.h".} = object
    active* {.importc.}: cint
    pending* {.importc.}: cint
    priority* {.importc.}: cint
    data* {.importc.}: pointer
    cb*: ev_prepare_cb

  # invoked for each run of the mainloop, just after the blocking call
  # revent EV_CHECK
  ev_check_cb* = proc(loop: ptr ev_loop_t, w: ptr ev_check, revents: cint): void {.cdecl.}
  ev_check* {.pure, final, importc, header: "ev.h".} = object
    active* {.importc.}: cint
    pending* {.importc.}: cint
    priority* {.importc.}: cint
    data* {.importc.}: pointer
    cb*: ev_check_cb

  # the callback gets invoked before check in the child process when a fork was detected
  # revent EV_FORK
  ev_fork_cb* = proc(loop: ptr ev_loop_t, w: ptr ev_fork, revents: cint): void {.cdecl.}
  ev_fork* {.pure, final, importc, header: "ev.h".} = object
    active* {.importc.}: cint
    pending* {.importc.}: cint
    priority* {.importc.}: cint
    data* {.importc.}: pointer
    cb*: ev_fork_cb

  # is invoked just before the loop gets destroyed
  # revent EV_CLEANUP
  ev_cleanup_cb* = proc(loop: ptr ev_loop_t, w: ptr ev_cleanup, revents: cint): void {.cdecl.}
  ev_cleanup* {.pure, final, importc, header: "ev.h".} = object
    active* {.importc.}: cint
    pending* {.importc.}: cint
    priority* {.importc.}: cint
    data* {.importc.}: pointer
    cb*: ev_cleanup_cb

  # used to embed an event loop inside another
  # the callback gets invoked when the event loop has handled events, and can be 0
  ev_embed_cb* = proc(loop: ptr ev_loop_t, w: ptr ev_embed, revents: cint): void {.cdecl.}
  ev_embed* {.pure, final, importc, header: "ev.h".} = object
    active* {.importc.}: cint
    pending* {.importc.}: cint
    priority* {.importc.}: cint
    data* {.importc.}: pointer
    cb*: ev_embed_cb
    other* {.importc.}: ptr ev_loop_t
    io* {.importc.}: ev_io
    prepare* {.importc.}: ev_prepare
    check* {.importc.}: ev_check
    timer* {.importc.}: ev_timer
    periodoc* {.importc.}: ev_periodic
    idle* {.importc.}: ev_idle
    fork* {.importc.}: ev_fork
    cleanup* {.importc.}: ev_cleanup

  # invoked when somebody calls ev_async_send on the watcher
  # revent EV_ASYNC
  sig_atomic* {.importc: "__sig_atomic_t", header: "sigset.h".} = cint
  sig_atomic_t* {.importc: "sig_atomic_t", header: "signal.h".} = sig_atomic
  ev_async_cb* = proc(loop: ptr ev_loop_t, w: ptr ev_async, revents: cint): void {.cdecl.}
  ev_async* {.pure, final, importc, header: "ev.h".} = object
    active* {.importc.}: cint
    pending* {.importc.}: cint
    priority* {.importc.}: cint
    data* {.importc.}: pointer
    cb*: ev_async_cb
    send* {.importc.}: sig_atomic_t

  # the presence of this union forces similar struct layout
  ev_any_watcher* {.pure, final, union, importc, header: "ev.h".} = object
    w* {.importc.}: ev_watcher
    wl* {.importc.}: ev_watcher_list
    io* {.importc.}: ev_io
    timer* {.importc.}: ev_timer
    periodoc* {.importc.}: ev_periodic
    signal* {.importc.}: ev_signal
    child* {.importc.}: ev_signal
    stat* {.importc.}: ev_stat
    idle* {.importc.}: ev_idle
    prepare* {.importc.}: ev_prepare
    check* {.importc.}: ev_check
    fork* {.importc.}: ev_fork
    cleanup* {.importc.}: ev_cleanup
    embed* {.importc.}: ev_embed
    async* {.importc.}: ev_async

type
  ev_set_allocator_cb* = proc(`ptr`: pointer, size: clong): void {.cdecl.}
  ev_set_syserr_cb_cb* = proc(msg: cstring): void {.cdecl.}
  ev_once_cb* = proc(revents: cint, arg: pointer): void {.cdecl.}
  ev_loop_callback* = proc(loop: ptr ev_loop_t): void {.cdecl.}
  ev_set_loop_release_release_cb* = proc(loop: ptr ev_loop_t): void {.cdecl.}
  ev_set_loop_release_acquire_cb* = proc(loop: ptr ev_loop_t): void {.cdecl.}

proc ev_version_major*(): cint
  {.importc, cdecl, dynlib: libev.}

proc ev_version_minor*(): cint
  {.importc, cdecl, dynlib: libev.}

proc ev_supported_backends*(): cuint
  {.importc, cdecl, dynlib: libev.}

proc ev_recommended_backends*(): cuint
  {.importc, cdecl, dynlib: libev.}

proc ev_embeddable_backends*(): cuint
  {.importc, cdecl, dynlib: libev.}

proc ev_time*(): ev_tstamp
  {.importc, cdecl, dynlib: libev.}

# sleep for a while
proc ev_sleep*(delay: ev_tstamp): void
  {.importc, cdecl, dynlib: libev.}

# Sets the allocation function to use, works like realloc.
# It is used to allocate and free memory.
# If it returns zero when memory needs to be allocated, the library might abort
# or take some potentially destructive action.
# The default is your system realloc function.
proc ev_set_allocator*(cb: ptr ev_set_allocator_cb): void
  {.importc, cdecl, dynlib: libev.}

# set the callback function to call on a
# retryable syscall error
# (such as failed select, poll, epoll_wait)
proc ev_set_syserr_cb*(cb: ev_set_syserr_cb_cb): void
  {.importc, cdecl, dynlib: libev.}

# the default loop is the only one that handles signals and child watchers
# you can call this as often as you like
proc ev_default_loop*(flags: cuint): ptr ev_loop_t
  {.importc, cdecl, dynlib: libev.}

proc ev_default_loop_uc*(): ptr ev_loop_t {.cdecl, inline.} =
  var ev_default_loop_ptr: ptr ev_loop_t
  return ev_default_loop_ptr

proc ev_is_default_loop*(loop: ptr ev_loop_t): cint {.cdecl, inline.} =
  return (loop == ev_default_loop_uc()).bool.cint

# create and destroy alternative loops that don't handle signals
proc ev_loop_new*(flags: cuint): ptr ev_loop_t
  {.importc, cdecl, dynlib: libev.}

proc ev_now*(loop: ptr ev_loop_t): ev_tstamp
  {.importc, cdecl, dynlib: libev.}

# destroy event loops, also works for the default loop
proc ev_loop_destroy*(loop: ptr ev_loop_t): void
  {.importc, cdecl, dynlib: libev.}

# this needs to be called after fork, to duplicate the loop
# when you want to re-use it in the child
# you can call it in either the parent or the child
# you can actually call it at any time, anywhere :)
proc ev_loop_fork*(loop: ptr ev_loop_t): void
  {.importc, cdecl, dynlib: libev.}

# backend in use by loop
proc ev_backend*(loop: ptr ev_loop_t): cuint
  {.importc, cdecl, dynlib: libev.}

# update event loop time
proc ev_now_update*(loop: ptr ev_loop_t): void
  {.importc, cdecl, dynlib: libev.}

# walk (almost) all watchers in the loop of a given type, invoking the
# callback on every such watcher. The callback might stop the watcher,
# but do nothing else with the loop
#proc ev_walk(types: cint, cb: pointer): void {.importc: "ev_walk", header: "ev.h".}

proc ev_run*(loop: ptr ev_loop_t, flags: cint): cint
  {.importc, cdecl, dynlib: libev.}

# break out of the loop
proc ev_break*(loop: ptr ev_loop_t, how: cint): void
  {.importc, cdecl, dynlib: libev.}

# ref/unref can be used to add or remove a refcount on the mainloop. every watcher
# keeps one reference. if you have a long-running watcher you never unregister that
# should not keep ev_loop from running, unref() after starting, and ref() before stopping.
proc ev_ref*(loop: ptr ev_loop_t): void
  {.importc, cdecl, dynlib: libev.}

proc ev_unref*(loop: ptr ev_loop_t): void
  {.importc, cdecl, dynlib: libev.}

# convenience function, wait for a single event, without registering an event watcher
# if timeout is < 0, do wait indefinitely
proc ev_once*(loop: ptr ev_loop_t, fd: cint, events: cint, timeout: ev_tstamp, cb: ev_once_cb, arg: pointer): void
  {.importc: "ev_once" cdecl, dynlib: libev.}

# number of loop iterations
proc ev_iteration*(loop: ptr ev_loop_t): cuint
  {.importc, cdecl, dynlib: libev.}

# #ev_loop enters - #ev_loop leaves
proc ev_depth*(loop: ptr ev_loop_t): cuint
  {.importc, cdecl, dynlib: libev.}

# about if loop data corrupted
proc ev_verify*(loop: ptr ev_loop_t): void
  {.importc, cdecl, dynlib: libev.}

# sleep at least this time, default 0
proc ev_set_io_collect_interval*(loop: ptr ev_loop_t, interval: ev_tstamp): void
  {.importc, cdecl, dynlib: libev.}

# sleep at least this time, default 0
proc ev_set_timeout_collect_interval*(loop: ptr ev_loop_t, interval: ev_tstamp): void
  {.importc, cdecl, dynlib: libev.}

# advanced stuff for threading etc. support, see docs
proc ev_set_userdata*(loop: ptr ev_loop_t, data: pointer): void
  {.importc, cdecl, dynlib: libev.}

proc ev_userdata*(loop: ptr ev_loop_t): pointer
  {.importc, cdecl, dynlib: libev.}

proc ev_set_invoke_pending_cb*(loop: ptr ev_loop_t, invoke_pending_cb: ev_loop_callback): void
  {.importc, cdecl, dynlib: libev.}

proc ev_set_loop_release_cb*(loop: ptr ev_loop_t, release: ev_set_loop_release_release_cb, acquire: ev_set_loop_release_acquire_cb): void
  {.importc, cdecl, dynlib: libev.}

# number of pending events, if any
proc ev_pending_count*(loop: ptr ev_loop_t): cuint
  {.importc, cdecl, dynlib: libev.}

# invoke all pending watchers
proc ev_invoke_pending*(loop: ptr ev_loop_t): void
  {.importc, cdecl, dynlib: libev.}

# stop/start the timer handling.
proc ev_suspend*(loop: ptr ev_loop_t): void
  {.importc, cdecl, dynlib: libev.}

proc ev_resume*(loop: ptr ev_loop_t): void
  {.importc, cdecl, dynlib: libev.}

# ev_* init method (from macro)
proc ev_io_init*(ev: ptr ev_io, cb: ev_io_cb, fd: cint, events: cint): void {.cdecl, inline.}=
  ev[].active = 0
  ev[].pending = 0
  ev[].priority = 0
  ev[].cb = cb
  ev[].fd = fd
  ev[].events = events or EV_IOFDSET

proc ev_timer_init*(ev: ptr ev_timer, cb: ev_timer_cb, after: ev_tstamp, repeat: ev_tstamp): void {.cdecl, inline.}=
  ev[].active = 0
  ev[].pending = 0
  ev[].priority = 0
  ev[].cb = cb
  ev[].at = after
  ev[].repeat = repeat

proc ev_periodic_init*(ev: ptr ev_periodic, cb: ev_periodic_cb, ofs: ev_tstamp, ival: ev_tstamp, rcb: ptr ev_periodic_rcb): void {.cdecl inline.}=
  ev[].active = 0
  ev[].pending = 0
  ev[].priority = 0
  ev[].cb = cb
  ev[].offset = ofs
  ev[].interval = ival
  ev[].reschedule_cb = rcb

proc ev_signal_init*(ev: ptr ev_signal, cb: ev_signal_cb, signum: cint): void {.cdecl, inline.}=
  ev[].active = 0
  ev[].pending = 0
  ev[].priority = 0
  ev[].cb = cb
  ev[].signum = signum

proc ev_child_init*(ev: ptr ev_child, cb: ev_child_cb, pid: cint, trace: cint): void {.cdecl, inline.}=
  ev[].active = 0
  ev[].pending = 0
  ev[].priority = 0
  ev[].cb = cb
  ev[].pid = pid
  ev[].flags = trace

proc ev_stat_init*(ev: ptr ev_stat, cb: ev_stat_cb, path: cstring, interval: ev_tstamp): void {.cdecl, inline.}=
  ev[].active = 0
  ev[].pending = 0
  ev[].priority = 0
  ev[].cb = cb
  ev[].path = path
  ev[].interval = interval

proc ev_idle_init*(ev: ptr ev_idle, cb: ev_idle_cb): void {.cdecl, inline.}=
  ev[].active = 0
  ev[].pending = 0
  ev[].priority = 0
  ev[].cb = cb

proc ev_prepare_init*(ev: ptr ev_prepare, cb: ev_prepare_cb): void {.cdecl, inline.}=
  ev[].active = 0
  ev[].pending = 0
  ev[].priority = 0
  ev[].cb = cb

proc ev_check_init*(ev: ptr ev_check, cb: ev_check_cb): void {.cdecl, inline.}=
  ev[].active = 0
  ev[].pending = 0
  ev[].priority = 0
  ev[].cb = cb

proc ev_embed_init*(ev: ptr ev_embed, cb: ev_embed_cb, other: ptr ev_loop_t): void {.cdecl, inline.}=
  ev[].active = 0
  ev[].pending = 0
  ev[].priority = 0
  ev[].cb = cb
  ev[].other = other

proc ev_fork_init*(ev: ptr ev_fork, cb: ev_fork_cb): void {.cdecl, inline.}=
  ev[].active = 0
  ev[].pending = 0
  ev[].priority = 0
  ev[].cb = cb

proc ev_cleanup_init*(ev: ptr ev_cleanup, cb: ev_cleanup_cb): void {.cdecl, inline.}=
  ev[].active = 0
  ev[].pending = 0
  ev[].priority = 0
  ev[].cb = cb

proc ev_async_init*(ev: ptr ev_async, cb: ev_async_cb): void {.cdecl, inline.}=
  ev[].active = 0
  ev[].pending = 0
  ev[].priority = 0
  ev[].cb = cb

# feeds an event into a watcher as if the event actually occurred
# accepts any ev_watcher type
proc ev_feed_event*(loop: ptr ev_loop_t, w: pointer, revents: cint): void
  {.importc, cdecl, dynlib: libev.}

proc ev_feed_fd_event*(loop: ptr ev_loop_t, w: pointer, revents: cint): void
  {.importc, cdecl, dynlib: libev.}

proc ev_feed_signal*(signum: cint): void
  {.importc, cdecl, dynlib: libev.}

proc ev_feed_signal_event*(loop: ptr ev_loop_t, signum: cint): void
  {.importc, cdecl, dynlib: libev.}

proc ev_invoke*(loop: ptr ev_loop_t, w: pointer, revents: cint): void
  {.importc, cdecl, dynlib: libev.}

proc ev_clear_pending*(loop: ptr ev_loop_t, w: pointer): cint
  {.importc, cdecl, dynlib: libev.}

proc ev_io_start*(loop: ptr ev_loop_t, w: ptr ev_io): void
  {.importc, cdecl, dynlib: libev.}

proc ev_io_stop*(loop: ptr ev_loop_t, w: ptr ev_io): void
  {.importc, cdecl, dynlib: libev.}

proc ev_timer_start*(loop: ptr ev_loop_t, w: ptr ev_timer): void
  {.importc, cdecl, dynlib: libev.}

proc ev_timer_stop*(loop: ptr ev_loop_t, w: ptr ev_timer): void
  {.importc, cdecl, dynlib: libev.}

# stops if active and no repeat, restarts if active and repeating, starts if inactive and repeating
proc ev_timer_again*(loop: ptr ev_loop_t, w: ptr ev_timer): void
  {.importc, cdecl, dynlib: libev.}

# return remaining time
proc ev_timer_remaining*(loop: ptr ev_loop_t, w: ptr ev_timer): ev_tstamp
  {.importc, cdecl, dynlib: libev.}

proc ev_periodic_start*(loop: ptr ev_loop_t, w: ptr ev_periodic): void
  {.importc, cdecl, dynlib: libev.}

proc ev_periodic_stop*(loop: ptr ev_loop_t, w: ptr ev_periodic): void
  {.importc, cdecl, dynlib: libev.}

proc ev_periodic_again*(loop: ptr ev_loop_t, w: ptr ev_periodic): void
  {.importc, cdecl, dynlib: libev.}

proc ev_signal_start*(loop: ptr ev_loop_t, w: ptr ev_signal): void
  {.importc, cdecl, dynlib: libev.}

proc ev_signal_stop*(loop: ptr ev_loop_t, w: ptr ev_signal): void
  {.importc, cdecl, dynlib: libev.}

proc ev_child_start*(loop: ptr ev_loop_t, w: ptr ev_child): void
  {.importc, cdecl, dynlib: libev.}

proc ev_child_stop*(loop: ptr ev_loop_t, w: ptr ev_child): void
  {.importc, cdecl, dynlib: libev.}

proc ev_stat_start*(loop: ptr ev_loop_t, w: ptr ev_stat): void
  {.importc, cdecl, dynlib: libev.}

proc ev_stat_stop*(loop: ptr ev_loop_t, w: ptr ev_stat): void
  {.importc, cdecl, dynlib: libev.}

proc ev_stat_stat*(loop: ptr ev_loop_t, w: ptr ev_stat): void
  {.importc, cdecl, dynlib: libev.}

proc ev_idle_start*(loop: ptr ev_loop_t, w: ptr ev_idle): void
  {.importc, cdecl, dynlib: libev.}

proc ev_idle_stop*(loop: ptr ev_loop_t, w: ptr ev_idle): void
  {.importc, cdecl, dynlib: libev.}

proc ev_prepare_start*(loop: ptr ev_loop_t, w: ptr ev_prepare): void
  {.importc, cdecl, dynlib: libev.}

proc ev_prepare_stop*(loop: ptr ev_loop_t, w: ptr ev_prepare): void
  {.importc, cdecl, dynlib: libev.}

proc ev_check_start*(loop: ptr ev_loop_t, w: ptr ev_check): void
  {.importc, cdecl, dynlib: libev.}

proc ev_check_stop*(loop: ptr ev_loop_t, w: ptr ev_check): void
  {.importc, cdecl, dynlib: libev.}

proc ev_fork_start*(loop: ptr ev_loop_t, w: ptr ev_fork): void
  {.importc, cdecl, dynlib: libev.}

proc ev_fork_stop*(loop: ptr ev_loop_t, w: ptr ev_fork): void
  {.importc, cdecl, dynlib: libev.}

proc ev_cleanup_start*(loop: ptr ev_loop_t, w: ptr ev_cleanup): void
  {.importc, cdecl, dynlib: libev.}

proc ev_cleanup_stop*(loop: ptr ev_loop_t, w: ptr ev_cleanup): void
  {.importc, cdecl, dynlib: libev.}

proc ev_embed_start*(loop: ptr ev_loop_t, w: ptr ev_embed): void
  {.importc, cdecl, dynlib: libev.}

proc ev_embed_stop*(loop: ptr ev_loop_t, w: ptr ev_embed): void
  {.importc, cdecl, dynlib: libev.}

proc ev_embed_sweep*(loop: ptr ev_loop_t, w: ptr ev_embed): void
  {.importc, cdecl, dynlib: libev.}

proc ev_async_start*(loop: ptr ev_loop_t, w: ptr ev_async): void
  {.importc, cdecl, dynlib: libev.}

proc ev_async_stop*(loop: ptr ev_loop_t, w: ptr ev_async): void
  {.importc, cdecl, dynlib: libev.}

proc ev_async_send*(loop: ptr ev_loop_t, w: ptr ev_async): void
  {.importc, cdecl, dynlib: libev.}

proc ev_loop*(loop: ptr ev_loop_t, flags: cint): void {.cdecl, inline.} =
  discard ev_run(loop, flags)

proc ev_unloop*(loop: ptr ev_loop_t, how: cint): void {.cdecl, inline.} =
  ev_break(loop, how)

proc ev_default_destroy*(): void {.cdecl, inline.} =
  ev_loop_destroy(ev_default_loop(0))

proc ev_default_fork*(): void {.cdecl, inline.} =
  ev_loop_fork(ev_default_loop(0))

proc ev_loop_count*(loop: ptr ev_loop_t): cuint {.cdecl, inline.} =
  ev_iteration(loop)

proc ev_loop_depth*(loop: ptr ev_loop_t): cuint {.cdecl, inline.} =
  ev_depth(loop)

proc ev_loop_verify*(loop: ptr ev_loop_t): void {.cdecl, inline.} =
  ev_verify(loop)