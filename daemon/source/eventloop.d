module eventloop;
import std.datetime : SysTime;

private
{
	void sleep(int ms)
	{
		import core.thread.osthread : Thread;
		import std.datetime : dur;

		Thread.sleep(dur!"msecs"(ms));
	}

	int lastTimerId;

	struct Timer
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
	Timer[] pendingTimers = [];

	void bgLoopFunc()
	{
		import tasks : currentTasks, internalData, saveInternals;
		import std.datetime : Clock, UTC;

		while (!cancelled)
		{
			if (nogcCbCount > 0)
			{
				for (auto i = 0; i < nogcCbCount;)
				{
					if (nogcCbs[i] == null)
						break;

					nogcCbs[i]();
					nogcCbs[i] = null;
				}

				nogcCbCount = 0;
			}

			if (pendingTimers.length > 0)
			{
				Timer[] notYet = [];

				foreach (timer; pendingTimers)
					if (timer.isReady)
						timer.cb();
					else
						notYet ~= timer;

				pendingTimers = notYet;
			}

			auto updatedInternals = false;

			foreach (task; currentTasks)
			{

				auto nextRun = task.getNextRun();
				if (nextRun <= Clock.currTime(UTC()))
				{
					import process : runCommand;

					updatedInternals = true;
					if (task.condition.isNull || runCommand(task.condition.get, task.as))
						runCommand(task.run, task.as);

					internalData.lastRunTimes[task.id] = nextRun;
				}
			}

			if (updatedInternals) saveInternals();

			sleep(100);
		}

		cancelled = false;
		pendingTimers = [];
	}
}

void runLoop()
{
	// lol infinite loops my beloved
	bgLoopFunc();
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
	auto id = lastTimerId++;

	pendingTimers ~= Timer(cb, time, id);

	return id;
}

void dequeueTimer(int id)
{
	Timer[] remaining = [];
	foreach (timer; pendingTimers)
		if (timer.id != id)
			remaining ~= timer;

	pendingTimers = remaining;
}
