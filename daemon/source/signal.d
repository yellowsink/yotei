module signal;

private void actualHandler()
{
	import core.stdc.stdlib : exit;
	import std.file : remove;
	import tasks : saveTasks;
	import eventloop : killLoop;

	//saveTasks();
	remove("/run/yotei.pid");
	killLoop();
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
