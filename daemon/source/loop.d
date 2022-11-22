module loop;
import std.typecons : Nullable;
import std.concurrency : Tid;
//import tanya.container.array : Array;
//import std.container.array : Array;

private
{
  struct KillMessage
  {
  }

  struct KillAckMessage
  {
  }

  struct StartAckMessage
  {
    Tid tid;
  }

  struct RunCbMessage
  {
    void function() cb;
  }

  // cbs can be added here from a nogc context
  // this is strongly dissuaded of use if possible to use message passing
  // due to having to wait for the timeout
  // and an arbitrary limit of 10 per loop
  __gshared void function()[10] nogcCbs;
  __gshared int nogcCbCount;

  Nullable!Tid bgThreadTid = Nullable!Tid.init;

  void bgThread(Tid parentTid)
  {
    //import core.sys.posix.unistd : sleep;
    import std.concurrency : receiveTimeout, send, thisTid;
    import core.time : dur;

    bool cancelled = false;

    send(parentTid, StartAckMessage(thisTid));

    while (!cancelled)
    {
      import std.stdio : writeln;
      import std.conv : text;

      if (nogcCbCount > 0)
      {
        for (auto i = 0; i < nogcCbCount; nogcCbs[i] != null)
        {
          nogcCbs[i]();
          nogcCbs[i] = null;
        }

        nogcCbCount = 0;
      }

      receiveTimeout(
        dur!"seconds"(1),
        (KillMessage _) { cancelled = true; send(parentTid, KillAckMessage()); },

        (RunCbMessage m) { m.cb(); }
      );
    }
  }
}

export void beginLoop()
{
  import std.concurrency : thisTid, receive;
  import std.parallelism : taskPool, task, Task;

  if (!bgThreadTid.isNull)
    return;

  auto t = task!bgThread(thisTid);
  t.executeInNewThread();
  taskPool.isDaemon = false;

  receive(
    (StartAckMessage m) {
      bgThreadTid = m.tid;
    }
  );
}

export void killLoop()
{
  import std.concurrency : send;

  if (bgThreadTid.isNull)
    throw new Exception("Tried to kill loop when it was not running");

  send(bgThreadTid.get(), KillMessage());
  waitForLoopClose();
  bgThreadTid.nullify();
}

export void waitForLoopClose()
{
  import std.concurrency : receive;

  receive(
    (KillAckMessage _) {}
  );
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
  // lol I should probably handle this
  assert(nogcCbCount < 10, "Only 10 nogc loop cbs can be queued at once.");

  nogcCbs[nogcCbCount] = cb;
  nogcCbCount++;
}
