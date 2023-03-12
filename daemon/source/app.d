void main(string[] argv)
{
	import config : init, pathPid;
	import std.file : remove, exists;

	init(hasFlag!"user"(argv));

	try {
		dirtyMain();
	}
	finally {
		if (exists(pathPid))
			remove(pathPid);

		// TODO: kill all dangling processes
	}
}

// dirty - can throw exceptions and require cleanup (pid file)
void dirtyMain()
{
	import std.file : exists, write, chdir;
	import std.conv : text;
	import std.stdio : stderr;
	import std.process : thisProcessID;
	import core.stdc.stdlib : exit;
	import signal : setupSignals;
	import eventloop : runLoop;
	import tasks : loadTasks, saveTasks;
	import config : init, rootDir, pathPid, expectRoot;
	import user : getuid;

	chdir(rootDir);

	if (exists(pathPid))
	{
		stderr.writeln(
			"An instance of the Yotei daemon appears to already be running. Do not try to start another.
(if you are SURE that the Yotei daemon is not running (try pgrep yoteid), then delete ", pathPid);

		return exit(1);
	}

	if (getuid() != 0 && expectRoot)
	{
		stderr.writeln(
			"The Yotei daemon should be started as root or with --user, Yotei *may* crash with a permission error.");
	}

	write(pathPid, thisProcessID.text);

	setupSignals();

	loadTasks();
	saveTasks();

	// start and supervise the event loop
	runLoop();
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
