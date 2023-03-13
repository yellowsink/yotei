module config;

import user : lookupCurrentUser;

string pathTasks;
string pathInternal;
string pathPid;
string pathSocket;
string rootDir;
bool expectRoot;

void init(bool user = false)
{
	import std.conv : to;

	expectRoot = !user;

	if (user)
	{
		auto currentUser = lookupCurrentUser();

		rootDir = currentUser.homedir;
		pathTasks = currentUser.homedir ~ "/.config/yotei/tasks";
		pathInternal = currentUser.homedir ~ "/.config/yotei/internal";
		pathPid = "/var/run/user/" ~ currentUser.uid.to!string ~ "/yotei.pid";
		pathSocket = "/var/run/user/" ~ currentUser.uid.to!string ~ "/yotei.sock";
	}
	else
	{
		rootDir = "/";
		pathTasks = "/etc/yotei/tasks";
		pathInternal = "/etc/yotei/internal";
		pathPid = "/var/run/yotei.pid";
		pathSocket = "/var/run/yotei.sock";
	}
}
