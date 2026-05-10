extension EnumeratedIterable<T> on Iterable<T> {
  Iterable<(int, T)> get enumerate sync* {
    var i = 0;
    for (final item in this) {
      yield (i++, item);
    }
  }
}