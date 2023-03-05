void main()
{
	import std.file : exists, write, chdir;
	import std.conv : text;
	import std.process : environment, thisProcessID;
	import core.stdc.stdlib : exit;
	import signal : setupSignals;
	import eventloop : beginLoop, queueTask;

	chdir("/");

	if (exists("/run/yotei.pid"))
	{
		import std.stdio : stderr;

		stderr.writeln(
			"An instance of the Yotei daemon is already running. Do not try to start another.");

		return exit(1);
	}

	if (environment.get("USER") != "root")
	{
		import std.stdio : stderr;

		stderr.writeln("The Yotei daemon should be started as root, Yotei *may* crash with a permission error.");
	}

	write("/run/yotei.pid", text(thisProcessID()));

	setupSignals();
	beginLoop();
	queueTask({
		import tasks : loadTasks;
		loadTasks();
	});
}
