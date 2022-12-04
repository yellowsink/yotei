module tasks;
import std.datetime;

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
  string as;
  ScheuleRule scheduleRule;
  Nullable!string condition;
  Nullable!Duration every;
  Nullable!Date once;
  Nullable!Duration at;

  // keep this as D:YAML will mimick the ingested code style on emit
  private Nullable!Node yamlRepresentation;

  // yaml
  this(const Node node, string tag) @safe
  {
    yamlRepresentation = node;

    id = node["id"].as!string;
    run = node["run"].as!string;
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
      every = resolveInterval(node["every"].as!string);
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

    // schedule rule might have been left as default!
    if (!("scheduleRule" in node) || scheduleRule != ScheuleRule.single)
      node["scheduleRule"] = emitScheduleRule(scheduleRule);

    if (!condition.isNull)
      node["condition"] = condition.get();
    else if ("condition" in node)
      node.removeAt("condition");
    
    //if ()

    return node;
  }
}

private
{
  @safe
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
        // ah huh. uh. 30? 31?
        // TODO
      case "months":
        return 1000 * 60 * 60 * 30;
        // leap years?
      case "years":
        return 1000 * 60 * 60 * 365;
      }
    }

    Duration resolveInterval(string interval)
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
  }

  static struct SysTimePackProxy
  {
    import msgpack : Packer, Unpacker;

    static void serialize(ref Packer p, ref in SysTime tim)
    {
      p.pack(tim.toISOExtString());
    }

    static void deserialize(ref Unpacker u, ref SysTime tim)
    {
      string tmp;
      u.unpack(tmp);
      tim = SysTime.fromISOExtString(tmp);
    }
  }

  struct TaskInternals
  {
    import msgpack : nonPacked, serializedAs;

    @nonPacked string id;
    @serializedAs!SysTimePackProxy SysTime last;

    this(SysTime last)
    {
      import std.datetime : Clock;

      this.last = last;
    }
  }

  Task[] loadTasks()
  {
    import std.file : exists;
    import dyaml : Loader;
    import std.algorithm : map;

    if (!exists("/etc/yotei/tasks"))
      return [];

    auto root = Loader.fromFile("/etc/yotei/tasks").load();

    auto tasks = new Task[0];

    foreach (Task task; root)
      tasks ~= task;

    return tasks;
  }

  TaskInternals loadInternals(string id)
  {
    import std.file : read;
    import msgpack : unpack;

    auto raw = cast(ubyte[]) read("/etc/yotei/internal");

    auto internals = raw.unpack!(TaskInternals[string]);

    auto target = internals[id];
    target.id = id;
    return target;
  }
}
