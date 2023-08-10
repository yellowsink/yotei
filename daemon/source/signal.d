module signal;
import core.stdc.signal : SIGTERM, SIGINT;

// the phobos binding of `signal()` requires @nogc which is a pain in the ass,
// and doesn't bind `sigaction()`, which is the more modern / portable way anyway.
// So I bound sigaction and sigset_t

extern (C)
{
  import core.sys.posix.sys.types : pid_t, uid_t;
	import core.sys.posix.time : timespec;

	alias sigset_t = int;

  union sigval
  {
    int sigval_int;
    void* sigval_ptr;
  }

  struct siginfo_t
  {
    int si_signo;
    int si_code;
    pid_t si_pid;
    uid_t si_uid;
    void* si_addr;
    int si_status;
    sigval si_value;
  }

  struct sigaction_t
  {
    void function(int) sa_handler;
    sigset_t sa_mask;
    int sa_flags;
    void function(int, siginfo_t*, void*) sa_sigaction;
  }

  int sigaction(int, sigaction_t*, sigaction_t*);

	int sigaddset(sigset_t*, int);
	int sigemptyset(sigset_t*);

	int sigtimedwait(sigset_t*, siginfo_t*, timespec*);
}

void setupSignals()
{
	// queue this on the loop to workaround @nogc limitations lol
	extern (C) void interopHandler(int) nothrow
	{
    import std.stdio : writeln;
    import core.memory : GC;

    // not sure if this is necessary but its probably a good thing to do to be safe
    // given that the phobos bindings for signal() take an @nogc handler.
    GC.disable();
    scope(exit) GC.enable();

		//__nogc__queueTask(&actualHandler);
    try
    {
      import core.stdc.stdlib : exit;
      import std.file : remove;
      import tasks : saveInternals;
      import eventloop : killLoop;
      import config : pathPid;

      //saveTasks(); this shouldn't be necessary?
      saveInternals();
      remove(pathPid);
      killLoop();
    }
    catch(Exception e)
    {
      try { writeln("errorred while catching signal: ", e); } catch (Exception) {}
    }
	}

  auto siginfo = sigaction_t();
  siginfo.sa_handler = &interopHandler;

  sigaction(SIGTERM, &siginfo, null);
  sigaction(SIGINT, &siginfo, null);
}
