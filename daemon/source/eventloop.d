module eventloop;
import std.typecons : Nullable;
import std.concurrency : Tid;
import std.datetime : SysTime;

private
{
	int lastId;

	int genId()
	{
		return lastId++;
	}

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

	struct QueueTimerMessage
	{
		void function() cb;
		SysTime at;
		int id;

		@property bool isReady()
		{
			import std.datetime : Clock;

			return Clock.currTime().toUnixTime() > at.toUnixTime();
		}
	}

	struct RemoveTimerMessage
	{
		int id;
	}

	// cbs can be added here from a nogc context
	// this is strongly dissuaded of use if possible to use message passing
	// due to having to wait for the timeout
	// and an arbitrary limit of 10 per loop
	immutable int nogcCbLimit = 10;
	__gshared void function()[nogcCbLimit] nogcCbs;
	__gshared int nogcCbCount;

	Nullable!Tid bgThreadTid = Nullable!Tid.init;

	void bgThread(Tid parentTid)
	{
		import std.concurrency : receiveTimeout, send, thisTid;
		import core.time : dur;

		bool cancelled = false;

		send(parentTid, StartAckMessage(thisTid));

		QueueTimerMessage[] pendingTimers = [];

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

			if (pendingTimers.length > 0)
			{
				QueueTimerMessage[] notYet = [];

				foreach (timer; pendingTimers)
					if (timer.isReady)
						timer.cb();
					else
						notYet ~= timer;

				pendingTimers = notYet;
			}

			receiveTimeout(
				dur!"seconds"(1),
				(KillMessage _) { cancelled = true; send(parentTid, KillAckMessage()); },

				(RunCbMessage m) { m.cb(); },
				(QueueTimerMessage m) { pendingTimers ~= m; },
				(RemoveTimerMessage m) {
				QueueTimerMessage[] remaining = [];
				foreach (timer; pendingTimers)
					if (timer.id != m.id)
						remaining ~= timer;

				pendingTimers = remaining;
			}
			);
		}
	}
}

void beginLoop()
{
	import std.concurrency : thisTid, receive;
	import std.parallelism : taskPool, task, Task;

	if (!bgThreadTid.isNull)
		return;

	auto t = task!bgThread(thisTid);
	t.executeInNewThread();
	taskPool.isDaemon = false;

	receive(
		(StartAckMessage m) { bgThreadTid = m.tid; }
	);
}

void killLoop()
{
	import std.concurrency : send;

	if (bgThreadTid.isNull)
		throw new Exception("Tried to kill loop when it was not running");

	send(bgThreadTid.get(), KillMessage());
	waitForLoopClose();
	bgThreadTid.nullify();
}

void waitForLoopClose()
{
	import std.concurrency : receive;

	receive(
		(KillAckMessage _) {}
	);
}

void queueTask(void function() cb)
{
	import std.concurrency : send;

	if (bgThreadTid.isNull)
		throw new Exception("Tried to run cb on loop when it was not running");

	send(bgThreadTid.get(), RunCbMessage(cb));
}

/// this really only exists for C interop, please dont use this :/
void __nogc__queueTask(void function() cb) @nogc nothrow
{
	// lol I should probably handle this
	assert(nogcCbCount < nogcCbLimit, "Only 10 nogc loop cbs can be queued at once.");

	nogcCbs[nogcCbCount] = cb;
	nogcCbCount++;
}

int queueTimer(void function() cb, SysTime time)
{
	import std.concurrency : send;

	if (bgThreadTid.isNull)
		throw new Exception("Tried to queue timer on loop when it was not running");

	auto id = genId();

	send(bgThreadTid.get(), QueueTimerMessage(cb, time, id));

	return id;
}

void dequeueTimer(int id)
{
	import std.concurrency : send;

	if (bgThreadTid.isNull)
		throw new Exception("Tried to dequeue timer from loop when it was not running");

	send(bgThreadTid.get(), RemoveTimerMessage(id));
}
