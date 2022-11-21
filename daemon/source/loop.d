module loop;
import std.typecons : Nullable;
import std.concurrency : Tid;

private
{
  struct KillMessage {}
  struct KillAckMessage {}
  struct RunCbMessage 
  {
    void function() cb;
  }

  Nullable!Tid bgThreadTid = Nullable!Tid.init;

  void bgThread(Tid parentTid)
  {
    //import core.sys.posix.unistd : sleep;
    import std.concurrency : receiveTimeout, send;
    import core.time : dur;

    bool cancelled = false;

    while (!cancelled)
    {
      import std.stdio : writeln;

      receiveTimeout(
        dur!"seconds"(3),
        (KillMessage _) {
          cancelled = true;
          send(parentTid, KillAckMessage());
        },

        (RunCbMessage m) {
          m.cb();
        }
      );
    }

    bgThreadTid.nullify();
  }
}

export void beginLoop()
{
  import std.concurrency : thisTid, spawn;

  if (!bgThreadTid.isNull)
    return;

  bgThreadTid = spawn(&bgThread, thisTid);
}

export void killLoop()
{
  import std.concurrency : send;

  if (bgThreadTid.isNull)
    throw new Exception("Tried to kill loop when it was not running");

  send(bgThreadTid.get(), KillMessage());
}

export void waitForLoopClose()
{
  import std.concurrency : receive, OwnerTerminated;

  try 
  {
    auto done = false;
    while (!done)
      receive(
        (KillAckMessage _) {
          done = true;
        }
      );

  } catch (OwnerTerminated)
  {
  }
}

export void runOnLoop(void function() cb)
{
  import std.concurrency : send;

  if (bgThreadTid.isNull)
    throw new Exception("Tried to run cb on loop when it was not running");
  
  send(bgThreadTid.get(), RunCbMessage(cb));
}