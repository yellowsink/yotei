void main(string[] argv)
{
	import std.file : remove, exists, write, chdir;
	import std.conv : text;
	import std.stdio : stderr;
	import std.process : thisProcessID;
	import core.stdc.stdlib : exit;
	import core.sys.posix.unistd : getuid;
	import signal : setupSignals;
	import eventloop : runLoop;
	import tasks : loadTasks, saveTasks;
	import config : init, rootDir, pathPid, expectRoot;

	init(argv.hasFlag!"user");

	chdir(rootDir);

	if (exists(pathPid))
	{
		stderr.writeln(
			"An instance of the Yotei daemon appears to already be running. Do not try to start another.
(if you are SURE that the Yotei daemon is not running (try pgrep yoteid), then delete ", pathPid);

		return exit(1);
	}

	scope(exit)
	{
		if (exists(pathPid)) remove(pathPid);
		// TODO: kill all dangling processes
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
