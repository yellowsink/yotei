module config;

string pathTasks;
string pathInternal;
string pathPid;
string rootDir;
bool expectRoot;

extern (C) uint getuid();

void init(bool user = false)
{
	import std.conv : to;

	expectRoot = !user;

	if (user)
	{
		import std.process : environment;
		auto homeDir = environment.get("HOME");
		if (homeDir is null)
		{
			import std.stdio : stderr;
			import core.stdc.stdlib : exit;

			stderr.writeln("Yotei was passed the --user flag, however cannot setup in user mode due to missing $HOME env var");
			exit(4);
		}

		rootDir = homeDir;
		pathTasks = homeDir ~ ".config/yotei/tasks";
		pathInternal = ".config/yotei/internal";
		pathPid = "/var/run/user/" ~ getuid().to!string ~ "/yotei.pid";
	}
	else {
		rootDir = "/";
		pathTasks = "/etc/yotei/tasks";
		pathInternal = "/etc/yotei/internal";
		pathPid = "/var/run/yotei.pid";
	}
}