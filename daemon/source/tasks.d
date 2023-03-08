module tasks;
import std.datetime;
import internalcoding;

enum ScheuleRule
{
	drop,
	single,
	always
}

struct Task
{
	import std.typecons : Nullable;
	import dyaml : Node;
	import std.conv : to;

	string id;
	string run;
	Nullable!string as;
	ScheuleRule scheduleRule;
	Nullable!string condition;
	Nullable!Duration everyMs;
	Nullable!uint everyMonths;
	Nullable!Date once;
	Nullable!Duration at;

	// keep this as D:YAML will mimick the ingested code style on emit
	private Nullable!Node yamlRepresentation;

	// yaml
	this(const Node node, string tag) @safe
	{
		import config : expectRoot;

		yamlRepresentation = node;

		id = node["id"].as!string;
		run = node["run"].as!string;

		if ((cast(bool) ("as" in node)) != expectRoot)
			throw new Exception("`as` may not be specified in user mode, but must be specified in root mode.");

		if ("as" in node)
			as = node["as"].as!string;

		if ("scheduleRule" in node)
			scheduleRule = parseScheduleRule(node["scheduleRule"].as!string);
		else
			scheduleRule = ScheuleRule.single;

		if ("condition" in node)
			condition = node["condition"].as!string;

		if (cast(bool)("every" in node) == cast(bool)("once" in node))
			throw new Exception("Supply only one of `once` or `every` to each task");

		if ("every" in node)
		{
			import std.algorithm.searching : canFind;

			auto ev = node["every"].as!string;

			if (ev.canFind("months") || ev.canFind("years"))
			{
				if (ev.canFind("weeks")
					|| ev.canFind("days")
					|| ev.canFind("hours")
					|| ev.canFind("minutes")
					|| ev.canFind("seconds"))
					throw new Exception("Cannot mix months with seconds in `every` - see docs for details");

				everyMs.nullify();
				everyMonths = resolveIntervalMonths(ev);
			}
			else
			{
				everyMonths.nullify();
				everyMs = resolveIntervalMs(ev);
			}
		}
		else
			once = node["once"].as!SysTime
				.to!Date;

		if ("at" in node)
			at = dur!"minutes"(node["at"].as!int);
	}

	Node toYaml() @safe
	{
		Node node = yamlRepresentation.get(Node(new Node.Pair[0]));

		node["id"] = id;
		node["run"] = run;

		if (!as.isNull)
			node["as"] = as.get;
		else if ("as" in node)
			node.removeAt("as");

		// schedule rule might have been left as default!
		if (!("scheduleRule" in node) || scheduleRule != ScheuleRule.single)
			node["scheduleRule"] = emitScheduleRule(scheduleRule);

		if (!condition.isNull)
			node["condition"] = condition.get();
		else if ("condition" in node)
			node.removeAt("condition");

		if (!everyMs.isNull)
		{
			if (!everyMonths.isNull)
				throw new Exception("Cannot emit a task that mixes months and ms in `every`");

			if (!("every" in node)
				|| resolveIntervalMs(node["every"].as!string) != everyMs
				)
				node["every"] = (everyMs.get.total!"msecs" / 1000.0).to!string ~ " seconds";

			if ("once" in node)
				node.removeAt("once");
		}
		else if (!everyMonths.isNull)
		{

			if (!("every" in node) || resolveIntervalMonths(node["every"].as!string) != everyMonths)
				node["every"] = everyMonths.to!string ~ " months";

			if ("once" in node)
				node.removeAt("once");
		}
		else if (once.isNull)
			throw new Exception("Cannot emit a task with neither `every` nor `once` keys");
		else
		{
			// unlike `every`, there's no reason to only update if needed
			// there, keeping the user's formatting of their interval is preferable
			// but here, its ISO all the time so its ok
			node["once"] = once.get.toISOExtString();
			if ("every" in node)
				node.removeAt("every");
		}

		if (!at.isNull)
		{
			auto mins = at.get.total!"minutes";
			auto secs = (at.get - dur!"minutes"(mins)).total!"seconds";

			node["at"] = mins.to!string ~ ":" ~ secs.to!string;
		}
		else if ("at" in node)
			node.removeAt("at");

		// keep this up to date!
		yamlRepresentation = node;

		return node;
	}
}

private @safe
{
	ScheuleRule parseScheduleRule(string str)
	{
		final switch (str)
		{
		case "drop":
			return ScheuleRule.drop;
		case "single":
			return ScheuleRule.single;
		case "always":
			return ScheuleRule.always;
		}
	}

	string emitScheduleRule(ScheuleRule s)
	{
		final switch (s)
		{
		case ScheuleRule.drop:
			return "drop";
		case ScheuleRule.single:
			return "single";
		case ScheuleRule.always:
			return "always";
		}
	}

	int intervalToMultiplier(string interval)
	{
		final switch (interval)
		{
		case "seconds":
			return 1000;
		case "minutes":
			return 1000 * 60;
		case "hours":
			return 1000 * 60 * 60;
		case "days":
			return 1000 * 60 * 60 * 24;
		case "weeks":
			return 1000 * 60 * 60 * 24 * 7;

		case "months":
			return 1;
		case "years":
			return 12;
		}
	}

	Duration resolveIntervalMs(string interval)
	{
		import std.array : split;

		auto splits = interval.split(" ");

		auto ms = 0;

		for (auto i = 0; i + 1 < splits.length; i += 2)
		{
			import std.conv : to;

			auto amount = to!double(splits[i]);
			auto multiplier = intervalToMultiplier(splits[i + 1]);

			ms += to!int(amount * multiplier);
		}

		return dur!"msecs"(ms);
	}

	uint resolveIntervalMonths(string interval)
	{
		import std.array : split;

		auto splits = interval.split(" ");

		auto months = 0;

		for (auto i = 0; i + 1 < splits.length; i += 2)
		{
			import std.conv : to;

			auto amount = to!uint(splits[i]);
			auto multiplier = intervalToMultiplier(splits[i + 1]);

			months += amount * multiplier;
		}

		return months;
	}
}

Task[string] currentTasks;

InternalV1 internalData;

void loadInternals()
{
	import std.file : read, exists;
	import config : pathInternal;

	if (!exists(pathInternal))
	{
		// assume yotei has never ran before if this is nulled out
		if (internalData.magic == [0, 0, 0, 0])
			internalData = InternalV1(0);

		return;
	}

	auto raw = cast(ubyte[]) read(pathInternal);

	internalData = deserInternal(raw);
}

void saveInternals()
{
	import std.file : write;
	import config : pathInternal;

	write(pathInternal, internalData.serIternal());
}

void loadTasks(bool andInternals = true)
{
	import std.file : exists;
	import dyaml : Loader;
	import dyaml.exception : YAMLException;
	import std.algorithm : map;
	import config : pathTasks;

	if (exists(pathTasks))
	{
		auto root = Loader.fromFile(pathTasks).load();

		foreach (Task task; root)
			currentTasks[task.id] = task;
	}

	if (andInternals)
		loadInternals();
}

void saveTasks(bool andInternals = true)
{
	import std.file : exists, write;
	import std.array : Appender, appender;
	import dyaml : dumper, Node;
	import config : pathTasks;

	auto taskList = Node(cast(Node[])[]);
	foreach (task; currentTasks.byValue)
		taskList.add(task.toYaml);

	auto buf = appender!string();

	dumper().dump(buf, taskList);

	write(pathTasks, buf[]);

	if (andInternals)
		saveInternals();
}
