/// Indexed mapping over an [Iterable].
extension MapIndexIterable<T, R> on Iterable<T> {
  /// Like [Iterable.map] but also passes a zero-based [index].
  Iterable<R> mapIndexed(R Function(int index, T e) transform) sync* {
    var index = 0;
    for (final element in this) {
      yield transform(index++, element);
    }
  }
}
