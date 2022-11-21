module signal;

export void catchSignals()
{
  import core.stdc.signal : signal, SIGTERM;
  import core.stdc.stdlib : exit;
  import std.file : remove;

  // use the loop as a workaround for signal handlers requiring @nogc
  
  extern(C) void handler(int) @nogc nothrow
  {
    /* import std.file : FileException;

    // TODO: stop supervised processes!
    try
    {
      remove("/run/yotei.pid");
    }
    catch(Exception)
    {
      import std.stdio : stderr;
      try
      {
        stderr.writeln("Failed to remove the pidfile. Yotei may fail to run again.");
      }
      catch(Exception) {}
    } */
    exit(0);
  }
  
  signal(SIGTERM, &handler);
}