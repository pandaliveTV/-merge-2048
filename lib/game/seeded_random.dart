/// Small deterministic PRNG (mulberry32).
///
/// Unlike `dart:math` Random, its whole state is a single 32-bit int, so it
/// can be saved with the board and restored by Undo. The same seed always
/// yields the same sequence, which is what makes the daily challenge
/// identical for every player.
class SeededRandom {
  int state;

  SeededRandom(int seed) : state = seed & 0xFFFFFFFF;

  static int _imul(int a, int b) => (a * b) & 0xFFFFFFFF;

  /// Next unsigned 32-bit value.
  int nextUint32() {
    state = (state + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = state;
    t = _imul(t ^ (t >>> 15), t | 1);
    t = (t ^ (t + _imul(t ^ (t >>> 7), t | 61))) & 0xFFFFFFFF;
    return (t ^ (t >>> 14)) & 0xFFFFFFFF;
  }

  /// Uniform double in [0, 1).
  double nextDouble() => nextUint32() / 4294967296.0;

  /// Uniform int in [0, max).
  int nextInt(int max) {
    assert(max > 0);
    return (nextDouble() * max).floor();
  }

  /// FNV-1a hash of [text], used to turn a date string into a seed.
  static int hashString(String text) {
    var h = 0x811C9DC5;
    for (final c in text.codeUnits) {
      h ^= c;
      h = _imul(h, 0x01000193);
    }
    return h;
  }
}
