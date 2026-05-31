const int maxU32 = 4294967295;

extension TypeBoundary on int {
  /// Clamp this number to comply u32 constant
  int complyU32() {
    return clamp(0, maxU32).toInt();
  }
}
