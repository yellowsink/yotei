module signal;
void actualHandler() {

  }
export void catchSignals()
{
  import core.stdc.signal : signal, SIGTERM;
  import core.stdc.stdlib : exit;
  import std.file : remove;


  // use the loop as a workaround for signal handlers requiring @nogc

  extern(C) void interopHandler(int) @nogc nothrow
  {
    import loop : runOnLoop;
    //runOnLoop(&actualHandler);
    
    exit(0);
  }
  
  signal(SIGTERM, &interopHandler);
}