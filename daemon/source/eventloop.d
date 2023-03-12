module eventloop;
import std.typecons : Nullable;
import core.thread.osthread : Thread;
import std.datetime : SysTime, dur;

private
{
	int lastId;

	int genId()
	{
		return lastId++;
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

	// cbs can be added here from a nogc context
	// this is strongly dissuaded of use if possible to use message passing
	// due to having to wait for the timeout
	// and an arbitrary limit of 10 per loop
	immutable int nogcCbLimit = 10;
	void function()[nogcCbLimit] nogcCbs;
	int nogcCbCount;

	bool cancelled = false;
	QueueTimerMessage[] pendingTimers = [];

	void bgThread()
	{
		import std.concurrency : receiveTimeout, send, thisTid;
		import core.time : dur;

		while (!cancelled)
		{
			import std.stdio : writeln;
			import std.conv : text;

			if (nogcCbCount > 0)
			{
				for (auto i = 0; i < nogcCbCount;)
				{
					if (nogcCbs[i] == null) break;

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

			Thread.sleep(dur!"msecs"(100));
		}

		cancelled = false;
		pendingTimers = [];
	}
}

void runLoop()
{
	// lol infinite loops my beloved
	bgThread();
}

void killLoop() @nogc nothrow
{
	cancelled = true;
}

/// This only exists for C interop, please dont use.
/// The purpose of queueing a task on the loop is to schedule standard D code to run
/// from within a @nogc nothrow (c interop) environment
void __nogc__queueTask(void function() cb) @nogc nothrow
{
	// lol I should probably handle this
	assert(nogcCbCount < nogcCbLimit, "Only 10 nogc loop cbs can be queued at once.");

	nogcCbs[nogcCbCount] = cb;
	nogcCbCount++;
}

int queueTimer(void function() cb, SysTime time)
{
	auto id = genId();

	pendingTimers ~= QueueTimerMessage(cb, time, id);

	return id;
}

void dequeueTimer(int id)
{
	QueueTimerMessage[] remaining = [];
	foreach (timer; pendingTimers)
		if (timer.id != id)
			remaining ~= timer;

	pendingTimers = remaining;
}
