extern (C)
{
	int getuid();
	int getgid();
	int geteuid();
	int getegid();
}

void main()
{
	import std.file : write, append;
	import std.process : environment;
	import std.conv : to;

	write("/tmp/envdump", []);

	append("/tmp/envdump", "uid:  " ~ getuid().to!string);
	append("/tmp/envdump", "\ngid:  " ~ getgid().to!string);
	append("/tmp/envdump", "\neuid: " ~ geteuid().to!string);
	append("/tmp/envdump", "\negid: " ~ getegid().to!string);
	append("/tmp/envdump", "\nenv HOME:    " ~ environment.get("HOME"));
	append("/tmp/envdump", "\nenv USER:    " ~ environment.get("USER"));
	append("/tmp/envdump", "\nenv UID:     " ~ environment.get("UID"));
	append("/tmp/envdump", "\nenv GID:     " ~ environment.get("GID"));
	append("/tmp/envdump", "\nenv LOGNAME: " ~ environment.get("LOGNAME"));
	append("/tmp/envdump", "\nenv MAIL:    " ~ environment.get("MAIL"));
}
