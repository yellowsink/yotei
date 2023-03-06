module signal;

// runs on event loop thread
private void actualHandler()
{
	import core.stdc.stdlib : exit;
	import std.file : remove;
	import tasks : saveTasks;

	saveTasks();
	remove("/run/yotei.pid");
	exit(0);
}

void setupSignals()
{
	import core.stdc.signal : signal, SIGTERM, SIGINT;

	// queue this on the background loop to workaround @nogc limitations lol
	extern (C) void interopHandler(int) @nogc nothrow
	{
		import eventloop : __nogc__queueTask;

		__nogc__queueTask(&actualHandler);
	}

	signal(SIGTERM, &interopHandler);
	signal(SIGINT, &interopHandler);
}
