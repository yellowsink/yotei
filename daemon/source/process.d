module process;

import std.typecons : Nullable;

T forkAsUser(T)(uint uid, uint gid, T delegate() cb)
{
	import core.sys.posix.unistd : fork, setgid, setuid;
	import core.sys.posix.sys.wait : waitpid;
	import core.stdc.stdlib : exit;

	static if (!is(T == void))
		T result;

	auto pid = fork();

	if (pid == 0)
	{
		// child process
		assert(setgid(gid) == 0);
		assert(setuid(uid) == 0);

		static if (is(T == void))
			cb();
		else
			result = cb();

		exit(0);
	}
	else
	{
		// yoteid parent process
		waitpid(pid, null, 0);
	}

	static if (!is(T == void))
		return result;
}

private T setupEnvironment(T)(Nullable!string user, T delegate() cb)
{
	import config : expectRoot;
	import core.sys.posix.unistd : getuid, getgid, setuid, setgid;
	import user : lookupUserName;
	import std.process : environment;
	import std.conv : to;

	if (!expectRoot) return cb();
	if (user.isNull)
		throw new Exception("Cannot run a process from root with a null target user.");

	auto lookedUp = lookupUserName(user.get);

	return forkAsUser(lookedUp.uid, lookedUp.gid, {
		import core.thread : Thread;
		import std.datetime : dur;
		Thread.sleep(dur!"seconds"(15));

		// TODO: don't wrap cb
		return cb();
	});

	/* // backup old env
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
	} */
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
