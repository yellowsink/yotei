module user;

import core.sys.posix.pwd : getpwnam, getpwuid, passwd;
import core.sys.posix.unistd : getuid;

struct UserInfo
{
	uint uid;
	uint gid;
	string uname;
	string homedir;
	string shellpath;

	this(passwd* fromC)
	{
		import std.conv : to;

		uid = fromC.pw_uid;
		gid = fromC.pw_gid;
		uname = fromC.pw_name.to!string;
		homedir = fromC.pw_dir.to!string;
		shellpath = fromC.pw_shell.to!string;
	}
}

UserInfo lookupUserName(string username)
{
	import std.string : toStringz;
	auto cstr = cast(char*) username.toStringz();
	return UserInfo(getpwnam(cstr));
}

UserInfo lookupUserId(uint uid)
{
	return UserInfo(getpwuid(uid));
}

UserInfo lookupCurrentUser()
{
	return lookupUserId(getuid());
}
