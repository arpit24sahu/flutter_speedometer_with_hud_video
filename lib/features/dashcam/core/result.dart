// Lightweight Result type for the dashcam feature.
// Re-exports the project's existing Result pattern for local use.
// Keeps the dashcam feature self-contained without depending on profile's core.

sealed class Result<T, F> {
  const Result();

  bool get isSuccess => this is Success<T, F>;
  bool get isFailure => this is Failure<T, F>;

  T get value {
    if (this is Success<T, F>) return (this as Success<T, F>).value;
    throw StateError('Called value on a Failure result');
  }

  F get failure {
    if (this is Failure<T, F>) return (this as Failure<T, F>).failure;
    throw StateError('Called failure on a Success result');
  }

  Result<U, F> map<U>(U Function(T) mapper) {
    return switch (this) {
      Success(value: final v) => Success(mapper(v)),
      Failure(failure: final f) => Failure(f),
    };
  }

  Result<U, F> flatMap<U>(Result<U, F> Function(T) mapper) {
    return switch (this) {
      Success(value: final v) => mapper(v),
      Failure(failure: final f) => Failure(f),
    };
  }

  U fold<U>(U Function(T) onSuccess, U Function(F) onFailure) {
    return switch (this) {
      Success(value: final v) => onSuccess(v),
      Failure(failure: final f) => onFailure(f),
    };
  }
}

final class Success<T, F> extends Result<T, F> {
  @override
  final T value;
  const Success(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Success<T, F> && other.value == value);
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => 'Success($value)';
}

final class Failure<T, F> extends Result<T, F> {
  @override
  final F failure;
  const Failure(this.failure);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Failure<T, F> && other.failure == failure);
  @override
  int get hashCode => failure.hashCode;
  @override
  String toString() => 'Failure($failure)';
}
