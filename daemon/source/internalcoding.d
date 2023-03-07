module internalcoding;

// responsible for the encoding of the internal state file on disk

// v1:
// 'yoti' magic bytes
// 0x01   version specifier
// u64    last loop run, unix time, UTC
// the special case of the last loop run = 0 means the loop has never run.

import std.datetime : SysTime;

private immutable ubyte[] MAGIC = [0x79, 0x6F, 0x74, 0x69];

struct InternalV1
{
	ubyte[4] magic;
	ubyte ver;
	SysTime lastLoopRun;

	this(ulong llr)
	{
		magic = MAGIC;
		ver = 1;
		lastLoopRun = SysTime.fromUnixTime(llr);
	}
}

InternalV1 deserInternal(ubyte[] file)
{
	if (file.length != 13)
		throw new Exception("the file is the wrong number of bytes");
	if (file[0 .. 4] != MAGIC)
		throw new Exception("magic bytes were incorrect for this file");
	if (file[5] != 1)
		throw new Exception("invalid version number in file");

	// this casting madness constructs a ulong from a byte array of relevant size
	auto lastLoopRun = *cast(ulong*) file[6 .. 6 + ulong.sizeof].ptr;

	return InternalV1(lastLoopRun);
}

ubyte[] serIternal(InternalV1 internal)
{
	ulong ulongLastLoopRun = internal.lastLoopRun.toUnixTime();
	auto bytesLastLoopRun = *cast(ubyte[ulong.sizeof]*)&ulongLastLoopRun;
	return internal.magic ~ [internal.ver] ~ bytesLastLoopRun;
}
