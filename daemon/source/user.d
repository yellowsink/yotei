module user;

// binds to relevant C apis and provides useful functions for users

extern (C)
{
	uint getuid();
	int setuid(uint uid);
	uint getgid();
	int setgid(uint gid);

	private struct CPasswd
	{
		char* pw_name;
		char* pw_passwd;
		uint pw_uid;
		uint pw_gid;
		char* pw_gecos;
		char* pw_dir;
		char* pw_shell;
	}

	private CPasswd* getpwnam(char* name);
	private CPasswd* getpwuid(uint uid);
}

struct UserInfo
{
	uint uid;
	uint gid;
	string uname;
	string homedir;
	string shellpath;

	this(CPasswd* fromC)
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
	auto chars = cast(char[]) username;
	return UserInfo(getpwnam(chars.ptr));
}

UserInfo lookupUserId(uint uid)
{
	return UserInfo(getpwuid(uid));
}

UserInfo lookupCurrentUser()
{
	return lookupUserId(getuid());
}
