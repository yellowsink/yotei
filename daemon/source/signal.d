module signal;

private void actualHandler() {
  import std.concurrency : thisTid;
  import std.stdio : writeln;
  import std.conv : text;
  import core.stdc.stdlib : exit;
  import std.file : remove;

  writeln(text(thisTid));
  exit(0);
}

export void setupSignals()
{
  import core.stdc.signal : signal, SIGTERM;

  // use the loop as a workaround for signal handlers requiring @nogc

  extern (C) void interopHandler(int) @nogc nothrow
  {
    import loop : __nogc__runOnLoop;

    __nogc__runOnLoop(&actualHandler);
  }

  signal(SIGTERM, &interopHandler);
}