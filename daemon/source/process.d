module process;

bool checkCondition(string condition, string as)
{
  import std.process : execute;
  
  // this will not cause any problems I am sure
  // file CVEs to trolleyzoom@yellows.ink
  auto res = execute(["su", as, "-c", condition]);

  return res.status == 0;
}

// TODO: oh god the actual runner needs to be quite robust, huh?
// TODO: hmmm tie it all together with tasks n stuff too
// TODO: socket :D