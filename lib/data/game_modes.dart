import '../game/seeded_random.dart';

/// A playable board configuration.
class GameMode {
  final String id;
  final int size;

  /// Player level needed to play this mode.
  final int unlockLevel;
  final bool daily;

  const GameMode({
    required this.id,
    required this.size,
    this.unlockLevel = 1,
    this.daily = false,
  });

  String get sizeLabel => '$size×$size';
}

class GameModes {
  static const classic = GameMode(id: 'classic4', size: 4);
  static const big = GameMode(id: 'big5', size: 5, unlockLevel: 3);
  static const huge = GameMode(id: 'huge6', size: 6, unlockLevel: 6);
  static const daily = GameMode(id: 'daily', size: 4, daily: true);

  /// Modes listed on the mode-select ("levels") screen.
  static const progression = [classic, big, huge];

  static GameMode byId(String id) => [
    ...progression,
    daily,
  ].firstWhere((m) => m.id == id, orElse: () => classic);
}

/// Daily challenge helpers. The day is taken in UTC so every player in the
/// world gets the same board (and the same spawn sequence) at the same time.
class DailyChallenge {
  static String dayKey([DateTime? now]) {
    final d = (now ?? DateTime.now()).toUtc();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}$m$day';
  }

  static int seedFor(String dayKey) =>
      SeededRandom.hashString('elitep-merge2048-$dayKey');

  /// Coins granted the first time the daily challenge is finished each day.
  static const completionBonus = 50;
}

/// Player level from total XP (sum of all finished round scores).
class PlayerLevel {
  static const xpPerStep = 2000;

  /// Level n needs xpPerStep * (n-1)^2 XP: 1→0, 2→2k, 3→8k, 4→18k, …
  static int levelFor(int xp) {
    var level = 1;
    while (xpFor(level + 1) <= xp) {
      level++;
    }
    return level;
  }

  static int xpFor(int level) => xpPerStep * (level - 1) * (level - 1);

  /// Progress (0..1) towards the next level.
  static double progress(int xp) {
    final l = levelFor(xp);
    final a = xpFor(l), b = xpFor(l + 1);
    return (xp - a) / (b - a);
  }
}
