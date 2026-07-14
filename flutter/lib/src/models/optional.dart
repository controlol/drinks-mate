/// Present/absent wrapper for optional, independently-clearable fields.
///
/// The app-layer analogue of Drift's `Value<T>` — lets [DrinksRepository]
/// distinguish "leave unchanged" from "set to null" without exposing a
/// `package:drift` type across the repository seam (D2: "Drift types never
/// reach widgets" — flutter-stack.md).
class Optional<T> {
  const Optional.value(T value)
      : _value = value,
        isPresent = true;
  const Optional.absent()
      : _value = null,
        isPresent = false;

  final T? _value;
  final bool isPresent;

  /// The wrapped value. Only meaningful when [isPresent] is true.
  T? get value => _value;

  @override
  bool operator ==(Object other) =>
      // Deliberately `Optional` (not `Optional<T>`): callers often compare a
      // literal like `Optional.value(4.5)` (inferred `Optional<double>`)
      // against a captured `Optional<double?>` — same present/value pair,
      // different type argument. The wrapped value's own `==` already
      // enforces meaningful equality.
      other is Optional &&
      other.isPresent == isPresent &&
      other._value == _value;

  @override
  int get hashCode => Object.hash(isPresent, _value);
}
