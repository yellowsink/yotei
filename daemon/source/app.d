void main()
{
	import std.file : exists, write, chdir;
	import std.conv : text;
	import std.process : environment, thisProcessID;
	import core.stdc.stdlib : exit;
	import signal : setupSignals;
	import eventloop : beginLoop, waitForLoopClose;
	import tasks : loadTasks;

	chdir("/");

	if (exists("/run/yotei.pid"))
	{
		import std.stdio : stderr;

		stderr.writeln(
			"An instance of the Yotei daemon appears to already be running. Do not try to start another.
(if you are SURE that the Yotei daemon is not running (try pgrep yoteid), then delete /run/yotei.pid)");

		return exit(1);
	}

	if (environment.get("USER") != "root")
	{
		import std.stdio : stderr;

		stderr.writeln("The Yotei daemon should be started as root, Yotei *may* crash with a permission error.");
	}

	write("/run/yotei.pid", text(thisProcessID()));

	setupSignals();

	//loadTasks();

	// start and supervise the event loop
	beginLoop();
	waitForLoopClose();
}
