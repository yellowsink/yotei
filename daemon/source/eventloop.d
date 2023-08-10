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

	bool cancelled = false;
	Timer[] pendingTimers = [];

	void bgLoopFunc()
	{
		import tasks : currentTasks, internalData, saveInternals;
		import std.datetime : Clock, UTC;

		while (!cancelled)
		{
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

			sleep(250);
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
