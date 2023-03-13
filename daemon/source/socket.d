module socket;

import std.socket : Socket, UnixAddress, AddressFamily, SocketType, SocketShutdown;
import config : pathSocket;
import core.thread : Thread;

private __gshared class LockWrapper(T)
{
	import core.sync.mutex : Mutex;

	private T internal;
	private Mutex mut;

	this(T init)
	{
		internal = init;
		mut = new Mutex();
	}

	void lockAndUse(void delegate(T value) cb)
	{
		mut.lock();
		cb(internal);
		mut.unlock();
	}

	void set(T value)
	{
		mut.lock();
		internal = value;
		mut.unlock();
	}
}

private __gshared LockWrapper!Socket sock;

private void socketThread()
{
	sock.lockAndUse((s) {
		s.send("helo worl");
	});
}

void initSocket()
{
	auto s = new Socket(AddressFamily.UNIX, SocketType.STREAM);
	s.bind(new UnixAddress(pathSocket));

	sock = new LockWrapper!Socket(s);

	auto thread = new Thread(&socketThread);
	thread.start();
}

void shutdownSocket()
{
	sock.lockAndUse((s) {
		s.shutdown(SocketShutdown.BOTH);
		s.close();
	});
}
