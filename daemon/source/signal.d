module signal;

private void actualHandler() {
  import std.concurrency : thisTid;
  import std.stdio : writeln;
  import std.conv : text;
  import core.stdc.stdlib : exit;
  import std.file : remove;

  writeln("handler is running on thread ", text(thisTid), ", intercepted SIGTERM");
  exit(0);
}

export void setupSignals()
{
  import core.stdc.signal : signal, SIGTERM;

  // queue this on the background loop to workaround @nogc limitations lol
  extern (C) void interopHandler(int) @nogc nothrow
  {
    import loop : __nogc__runOnLoop;

    __nogc__runOnLoop(&actualHandler);
  }

  signal(SIGTERM, &interopHandler);
}