module process;

import std.typecons : Nullable;

private T* createSharedMemory(T)()
{
	import core.sys.posix.sys.mman : mmap, PROT_READ, PROT_WRITE, MAP_SHARED, MAP_ANON;

	// https://stackoverflow.com/a/5656561/8388655
	return cast(T*) mmap(null, T.sizeof, PROT_READ | PROT_WRITE, MAP_ANON | MAP_SHARED, -1, 0);
}

private T forkAsUser(T)(uint uid, uint gid, T delegate() cb)
{
	import core.sys.posix.unistd : fork, setgid, setuid;
	import core.sys.posix.sys.wait : waitpid;
	import core.stdc.stdlib : exit;
	import core.sys.posix.sys.mman : munmap;

	static if (!is(T == void))
	{
		T* result = createSharedMemory!T();
		*result = T.init;
	}

	auto pid = fork();

	if (pid == 0)
	{
		// child process
		assert(setgid(gid) == 0);
		assert(setuid(uid) == 0);

		static if (is(T == void))
			cb();
		else
			*result = cb();

		exit(0);
	}
	else
	{
		// yoteid parent process
		waitpid(pid, null, 0);
	}

	static if (!is(T == void))
	{
		auto res = *result;
		munmap(result, T.sizeof);
		return res;
	}
}

private T setupEnvironment(T)(Nullable!string user, T delegate() cb)
{
	import config : expectRoot;
	import user : lookupUserName;
	import std.process : environment;
	import std.conv : to;

	if (!expectRoot)
		return cb();
	if (user.isNull)
		throw new Exception("Cannot run a process from root with a null target user.");

	auto lookedUp = lookupUserName(user.get);

	return forkAsUser(lookedUp.uid, lookedUp.gid, {
		import std.process : environment;

		environment["HOME"] = lookedUp.homedir;
		environment["USER"] = lookedUp.uname;
		environment["UID"] = lookedUp.uid.to!string;
		environment["GID"] = lookedUp.gid.to!string;
		environment["LOGNAME"] = lookedUp.uname;

		return cb();
	});
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
