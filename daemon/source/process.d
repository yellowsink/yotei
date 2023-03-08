module process;

import std.typecons : Nullable;

private T setupEnvironment(T)(Nullable!string user, T delegate() cb)
{
	import config : expectRoot;
	import user : getuid, getgid, setuid, setgid, lookupUserName;
	import std.process : environment;
	import std.conv : to;

	if (!expectRoot) return cb();
	if (user.isNull)
		throw new Exception("Cannot run a process from root with a null target user.");

	// backup old env
	auto uidbefore = getuid();
	auto gidbefore = getgid();
	auto oldhomeenv = environment.get("HOME");
	auto olduserenv = environment.get("USER");
	auto olduidenv = environment.get("UID");
	auto oldgidenv = environment.get("GID");
	auto oldlognameenv = environment.get("LOGNAME");
	//auto oldmailenv = environment.get("MAIL");

	// setup new env
	auto lookedUp = lookupUserName(user.get);
	setuid(lookedUp.uid);
	setgid(lookedUp.gid);
	environment["HOME"] = lookedUp.homedir;
	environment["USER"] = lookedUp.uname;
	environment["UID"] = lookedUp.uid.to!string;
	environment["GID"] = lookedUp.gid.to!string;
	environment["LOGNAME"] = lookedUp.uname;
	//environment["MAIL"] = "/var/spool/main/" ~ lookedUp.uname;

	try
	{
		auto res = cb();
		return res;
	}
	finally
	{
		// cleanup user env
		setuid(uidbefore);
		setgid(gidbefore);
		environment["HOME"] = oldhomeenv;
		environment["USER"] = olduserenv;
		environment["UID"] = olduidenv;
		environment["GID"] = oldgidenv;
		environment["LOGNAME"] = oldlognameenv;
	}
}

bool runCommand(string command, Nullable!string as)
{
	return setupEnvironment(as, {
		import std.process : execute;

		auto res = execute(["bash", "-c", command]);
		return res.status == 0;
	});
}

void runTask(string task, Nullable!string as)
{
	auto _ = runCommand(task, as);
}

// TODO: logging
// TODO: open processes in parallel / on another thread / async?
