import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../data/game_modes.dart';
import '../services/storage_service.dart';
import 'board.dart';
import 'hint.dart';

/// What a finished round gave the player.
class RoundResult {
  final int coins;
  final int dailyBonus;
  final int? newLevel;

  const RoundResult({required this.coins, this.dailyBonus = 0, this.newLevel});
}

/// Game state for one board: moves, undo, hints, continue, win/lose and
/// persistence. Screens only call methods here and render the result.
class GameController extends ChangeNotifier {
  static const freeUndos = 3;
  static const undosPerAd = 2;
  static const hintCost = 30;
  static const continueRemoves = 4;
  static const winValue = 2048;
  static const _maxHistory = 30;

  final GameMode mode;
  final StorageService storage;
  final String? dayKey;
  final HintEngine _hints;

  late Board board;
  final _history = <BoardSnapshot>[];

  int undosLeft = freeUndos;
  bool continueUsed = false;
  bool wonShown = false;
  bool showWin = false;
  bool gameOver = false;
  bool coinsClaimed = false;
  Direction? hint;

  /// Animation data for the last change of the board.
  List<Tile> ghosts = const [];
  Set<int> mergedIds = const {};
  Set<int> spawnedIds = const {};

  /// Increments on every board change so the view can restart animations.
  int serial = 0;

  GameController({required this.mode, required this.storage, DateTime? now})
    : dayKey = mode.daily ? DailyChallenge.dayKey(now) : null,
      _hints = HintEngine(mode.size) {
    if (!_restore()) _start();
  }

  // ---------------- Derived state ----------------
  int get score => board.score;

  int get best => math.max(
    score,
    mode.daily ? storage.dailyBest(dayKey!) : storage.best(mode.id),
  );

  bool get undoAllowed => !mode.daily && _history.isNotEmpty && !coinsClaimed;

  bool get canContinue =>
      gameOver && !mode.daily && !continueUsed && !coinsClaimed;

  /// Coins for the current score: 1 per 100 points + a bonus for big tiles.
  int get roundCoins {
    final m = board.maxTile;
    final bonus = m >= 4096
        ? 300
        : m >= 2048
        ? 150
        : m >= 1024
        ? 50
        : m >= 512
        ? 20
        : 0;
    return score ~/ 100 + bonus;
  }

  // ---------------- Lifecycle ----------------
  void _start() {
    final seed = mode.daily
        ? DailyChallenge.seedFor(dayKey!)
        : math.Random().nextInt(1 << 32);
    board = Board.newGame(mode.size, seed);
    _history.clear();
    undosLeft = freeUndos;
    continueUsed = false;
    wonShown = false;
    showWin = false;
    gameOver = false;
    coinsClaimed = false;
    hint = null;
    ghosts = const [];
    mergedIds = const {};
    spawnedIds = board.tiles.map((t) => t.id).toSet();
    serial++;
    _save();
  }

  bool _restore() {
    final data = storage.loadGame(mode.id);
    if (data == null) return false;
    if (mode.daily && data['day'] != dayKey) return false;
    try {
      board = Board.fromJson(Map<String, dynamic>.from(data['board'] as Map));
      if (board.size != mode.size) return false;
      undosLeft = data['undos'] as int? ?? freeUndos;
      continueUsed = data['continueUsed'] as bool? ?? false;
      wonShown = data['wonShown'] as bool? ?? false;
      gameOver = !board.canMove;
      spawnedIds = const {};
      return true;
    } catch (_) {
      return false;
    }
  }

  void _save() {
    storage.saveGame(mode.id, {
      'board': board.toJson(),
      'undos': undosLeft,
      'continueUsed': continueUsed,
      'wonShown': wonShown,
      'day': ?dayKey,
    });
  }

  void _changed() {
    serial++;
    notifyListeners();
  }

  // ---------------- Actions ----------------
  MoveOutcome move(Direction d) {
    if (gameOver || showWin) return MoveOutcome.none;
    final before = board.snapshot();
    final outcome = board.move(d);
    if (!outcome.moved) return outcome;

    _history.add(before);
    if (_history.length > _maxHistory) _history.removeAt(0);
    hint = null;
    ghosts = outcome.ghosts;
    mergedIds = outcome.mergedIds;
    spawnedIds = {?outcome.spawnedId};

    if (mode.daily) {
      storage.submitDaily(dayKey!, score);
    } else {
      storage.submitBest(mode.id, score);
    }
    if (!wonShown && board.maxTile >= winValue) {
      wonShown = true;
      showWin = true;
    }
    if (!board.canMove) gameOver = true;
    _save();
    _changed();
    return outcome;
  }

  /// Uses one undo. The caller handles the "watch an ad for more" flow
  /// when [undosLeft] is 0.
  bool undo() {
    if (!undoAllowed || undosLeft <= 0) return false;
    board.restore(_history.removeLast());
    undosLeft--;
    gameOver = false;
    showWin = false;
    hint = null;
    ghosts = const [];
    mergedIds = const {};
    spawnedIds = const {};
    _save();
    _changed();
    return true;
  }

  void grantUndos([int n = undosPerAd]) {
    undosLeft += n;
    _save();
    notifyListeners();
  }

  /// "Continue" after losing: removes the smallest tiles.
  void continueGame() {
    if (!canContinue) return;
    final removed = board.removeSmallest(continueRemoves);
    continueUsed = true;
    gameOver = !board.canMove;
    _history.clear();
    ghosts = const [];
    mergedIds = const {};
    spawnedIds = const {};
    if (removed.isNotEmpty) _save();
    _changed();
  }

  void keepGoing() {
    showWin = false;
    notifyListeners();
  }

  /// Computes a suggested direction (does not consume the board's RNG).
  Direction? computeHint() {
    hint = _hints.bestMove(board.toGrid());
    notifyListeners();
    return hint;
  }

  /// Ends the round: pays coins + XP, records daily result, clears the save.
  /// Returns null when the round was already paid.
  RoundResult? finishRound({bool doubled = false}) {
    if (coinsClaimed) return null;
    coinsClaimed = true;
    final coins = roundCoins * (doubled ? 2 : 1);
    var dailyBonus = 0;
    if (mode.daily) {
      storage.submitDaily(dayKey!, score);
      if (score > 0 && storage.claimDailyBonus(dayKey!)) {
        dailyBonus = DailyChallenge.completionBonus;
      }
    } else {
      storage.submitBest(mode.id, score);
    }
    if (coins + dailyBonus > 0) storage.addCoins(coins + dailyBonus);
    final newLevel = storage.addXp(score);
    storage.clearGame(mode.id);
    notifyListeners();
    return RoundResult(
      coins: coins,
      dailyBonus: dailyBonus,
      newLevel: newLevel,
    );
  }

  /// Starts over. Pays the current round first if it had any progress.
  RoundResult? newGame() {
    final result = score > 0 ? finishRound() : null;
    _start();
    notifyListeners();
    return result;
  }
}
