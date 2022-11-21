module safestack;

export synchronized class SafeStack(T)
{
  import std.container.array : Array;
  import std.typecons : Tuple, tuple;

  private auto elements = Array!(shared(T))();

  void push(T value) @nogc
  {
    elements.insert(value);
  }

  bool content() {
    return !elements.empty;
  }

  Tuple!(bool, T) pop() 
  {
    T value;
    if (elements.empty)
      return tuple(false, value);
    
    value = elements.removeAny;
    return tuple(true, value);
  }
}