void main()
{
  import std.file : exists, write;
  import std.conv : text;
  import core.stdc.stdlib : exit;
  import signal : setupSignals;
  import loop : beginLoop, waitForLoopClose;

  /* if (exists("/run/yotei.pid")) 
  {
    import std.stdio : stderr;
    stderr.writeln("An instance of the Yotei daemon is already running. Do not try to start another.");

    return exit(1);
  }

  import std.process : environment, thisProcessID;

  if (environment.get("EUID") != "0") 
  {
    import std.stdio : stderr;

    stderr.writeln("The Yotei daemon should be started as root.");

    return exit(2);
  }

  write("/run/yotei.pid", text(thisProcessID())); */

  setupSignals();
  beginLoop();

  waitForLoopClose();
}
