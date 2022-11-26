module tasks;
import std.datetime : dur, Duration, TimeOfDay;

enum ScheuleRule
{
  drop,
  single,
  always
}

private ScheuleRule parseScheduleRule(string str) @safe
{
  final switch (str)
  {
  case "drop":
    return ScheuleRule.drop;
  case "sigle":
    return ScheuleRule.single;
  case "always":
    return ScheuleRule.always;
  }
}

private int intervalToMultiplier(string interval) @safe
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
    // ah huh. uh. 30? 31?
    // TODO
  case "months":
    return 1000 * 60 * 60 * 30;
    // leap years?
  case "years":
    return 1000 * 60 * 60 * 365;
  }
}

private Duration resolveInterval(string interval) @safe
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

private Duration todToDur(TimeOfDay tod) @safe
{
  import std.datetime : dur;

  return dur!"hours"(tod.hour) + dur!"minutes"(tod.minute) + dur!"seconds"(tod.second);
}

struct Task
{
  import std.typecons : Nullable;
  import std.datetime : Date, SysTime;
  import dyaml : Node;
  import std.conv : to;

  string id;
  string run;
  ScheuleRule scheduleRule;
  Nullable!string condition;
  Nullable!Duration every;
  Nullable!Date on;
  Nullable!Duration at;

  // yaml
  this(const Node node, string tag) @safe
  {
    id = node["id"].as!string;
    run = node["run"].as!string;

    scheduleRule = parseScheduleRule(node["scheduleRule"].as!string);

    if ("condition" in node)
      condition = node["condition"].as!string;

    if (("every" in node) == ("on" in node))
      throw new Exception("Supply only one of `on` or `every` to each task");

    if ("every" in node)
      every = resolveInterval(node["every"].as!string);
    else
      on = node["on"].as!SysTime
        .to!Date;

    if ("at" in node)
      at = todToDur(node["at"].as!SysTime.to!TimeOfDay);
  }
}
