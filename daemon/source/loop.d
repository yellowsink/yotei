module loop;
import std.typecons : Nullable;
import std.concurrency : Tid;
import safestack : SafeStack;

private
{
  struct KillMessage
  {
  }

  struct KillAckMessage
  {
  }

  struct RunCbMessage
  {
    void function() cb;
  }

  shared auto cbs = new SafeStack!(void function())();

  Nullable!Tid bgThreadTid = Nullable!Tid.init;

  void bgThread(Tid parentTid)
  {
    //import core.sys.posix.unistd : sleep;
    import std.concurrency : receiveTimeout, send;
    import core.time : dur;
    import std.concurrency : thisTid;

    bgThreadTid = thisTid;

    bool cancelled = false;

    while (!cancelled)
    {
      import std.stdio : writeln;
      import std.conv : text;

      writeln(text(cbs.length));

      if (cbs.length > 0)
      {

        foreach (cb; cbs)
        {
          cb();
        }

        cbs.clear();
      }

      receiveTimeout(
        dur!"seconds"(3),
        (KillMessage _) { cancelled = true; send(parentTid, KillAckMessage()); },

        (RunCbMessage m) { m.cb(); }
      );
    }

    bgThreadTid.nullify();
  }
}

export void beginLoop()
{
  import std.concurrency : thisTid;
  import std.parallelism : taskPool, task, Task;

  if (!bgThreadTid.isNull)
    return;

  auto t = task!bgThread(thisTid);
  t.executeInNewThread();
  taskPool.isDaemon = false;

  //bgThreadTid = spawn(&bgThread, thisTid);

  import std.stdio : writeln;
  import std.conv : text;

  writeln(text(thisTid));
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
  import std.concurrency : receive, OwnerTerminated, yield;

  try
  {
    auto done = false;
    while (!done)
    {
      receive(
        (KillAckMessage _) { done = true; }
      );
    }

  }
  catch (OwnerTerminated)
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

/// this really only exists for C interop, please dont use this :/
export void __nogc__runOnLoop(void function() cb) @nogc nothrow
{
  cbs.insert(cb);
}
