module signal;

private void actualHandler() {
  import std.concurrency : thisTid;
  import std.stdio : writeln;
  import std.conv : text;

  writeln(text(thisTid));
}

export void setupSignals()
{
  import std.concurrency : spawn;

  spawn({
    import core.stdc.signal : signal, SIGTERM;
    import core.stdc.stdlib : exit;
    import std.file : remove;

    // use the loop as a workaround for signal handlers requiring @nogc

    extern (C) void interopHandler(int) @nogc nothrow
    {
      import loop : __nogc__runOnLoop;

      try
      {
        __nogc__runOnLoop(&actualHandler);
      }
      catch (Exception)
      {
        exit(3);
      }
    }

    signal(SIGTERM, &interopHandler);
  });
}