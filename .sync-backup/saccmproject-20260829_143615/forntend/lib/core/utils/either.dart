abstract class Either<L, R> {
  const Either();
  
  bool get isLeft => this is Left<L, R>;
  bool get isRight => this is Right<L, R>;
  
  L get left => (this as Left<L, R>).value;
  R get right => (this as Right<L, R>).value;
  
  T fold<T>(T Function(L) leftFunction, T Function(R) rightFunction) {
    if (isLeft) {
      return leftFunction(left);
    } else {
      return rightFunction(right);
    }
  }
}

class Left<L, R> extends Either<L, R> {
  final L value;
  
  const Left(this.value);
  
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Left && runtimeType == other.runtimeType && value == other.value;
  }
  
  @override
  int get hashCode => value.hashCode;
}

class Right<L, R> extends Either<L, R> {
  final R value;
  
  const Right(this.value);
  
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Right && runtimeType == other.runtimeType && value == other.value;
  }
  
  @override
  int get hashCode => value.hashCode;
}
