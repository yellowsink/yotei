module internalcoding;

// responsible for the encoding of the internal state file on disk

// v1:
// 'yoti' magic bytes
// 0x01   version specifier
// u16    amount of tasks listed
// []:
//   u16  string length
//   u8[] UTF-8 ID string
//   u64  last time run, unix time, UTC

import std.datetime : SysTime;
import std.traits : isNumeric;

private immutable ubyte[] MAGIC = [0x79, 0x6F, 0x74, 0x69];

private ubyte[T.sizeof] byteify(T)(T value) if (isNumeric!T)
{
	// if this or debyteify(T)(T) are a genuine security concern
	// please god someone tell me
	// but im like 98% sure these are fine
  return *cast(ubyte[T.sizeof]*)&value;
}

private ubyte[] byteify(string value)
{
  import std.string : representation;

  auto repr = value.representation;

  return byteify(cast(ushort) repr.length) ~ repr;
}

private T debyteify(T)(ubyte[] value) if (isNumeric!T)
{
  return *cast(T*) value[0 .. T.sizeof].ptr;
}

private string debyteify(ubyte[] value, out ushort length)
{
  import std.string : assumeUTF;

  length = value.debyteify!ushort;

  return value[ushort.sizeof .. ushort.sizeof + length].assumeUTF;
}

struct InternalV1
{
  ubyte[4] magic;
  ubyte ver;
  SysTime[string] lastRunTimes;

  this(SysTime[string] lrts)
  {
    magic = MAGIC;
    ver = 1;
    lastRunTimes = lrts;
  }
}

InternalV1 deserInternal(ubyte[] file)
{
  if (file.length < 7)
    throw new Exception("the file is too short");
  if (file[0 .. 4] != MAGIC)
    throw new Exception("magic bytes were incorrect for this file");
  if (file[4] != 1)
    throw new Exception("invalid version number in file");

  auto taskCount = file[5 .. 7].debyteify!ushort;

  SysTime[string] lrts;

	int bytePos = 7;

  for (auto i = 0; i < taskCount; i++)
  {
		import std.datetime : SysTime;

		ushort consumed;
		auto taskId = file[bytePos .. $].debyteify(consumed);
		auto lastRun = file[bytePos + consumed .. $].debyteify!ulong;

		lrts[taskId] = SysTime.fromUnixTime(lastRun);

		bytePos += consumed + ulong.sizeof;
  }

  return InternalV1(lrts);
}

ubyte[] serIternal(InternalV1 internal)
{
  ubyte[] tasks = [];
  foreach (key, val; internal.lastRunTimes)
    tasks ~= key.byteify ~ [cast(ubyte) 0] ~ val.toUnixTime.byteify;

  auto taskCount = cast(ushort) internal.lastRunTimes.length;

  return internal.magic ~ [internal.ver] ~ taskCount.byteify ~ tasks;
}
