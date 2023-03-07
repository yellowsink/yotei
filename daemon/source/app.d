void main(string[] argv)
{
	import std.file : exists, write, chdir;
	import std.conv : text;
	import std.process : thisProcessID;
	import core.stdc.stdlib : exit;
	import signal : setupSignals;
	import eventloop : beginLoop, waitForLoopClose;
	import tasks : loadTasks;
	import config : init, rootDir, pathPid, expectRoot, getuid;

	init(hasFlag!"user"(argv));

	chdir(rootDir);

	if (exists(pathPid))
	{
		import std.stdio : stderr;

		stderr.writeln(
			"An instance of the Yotei daemon appears to already be running. Do not try to start another.
(if you are SURE that the Yotei daemon is not running (try pgrep yoteid), then delete ", pathPid);

		return exit(1);
	}

	if (getuid() != 0 && expectRoot)
	{
		import std.stdio : stderr;

		stderr.writeln(
			"The Yotei daemon should be started as root or with --user, Yotei *may* crash with a permission error.");
	}

	write(pathPid, text(thisProcessID()));

	setupSignals();

	loadTasks();

	// start and supervise the event loop
	beginLoop();
	waitForLoopClose();
}

bool hasFlag(string flag)(string[] argv)
{
	auto first = true;

	foreach (arg; argv)
	{
		if (first)
		{
			first = false;
			continue;
		}

		if (arg == ("--" ~ flag))
			return true;
	}

	return false;
}
