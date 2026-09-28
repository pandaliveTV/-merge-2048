import 'package:flutter_test/flutter_test.dart';
import 'package:merge2048/data/game_modes.dart';
import 'package:merge2048/data/strings.dart';
import 'package:merge2048/game/board.dart';
import 'package:merge2048/game/game_controller.dart';
import 'package:merge2048/services/ad_policy.dart';
import 'package:merge2048/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AdPolicy', () {
    late DateTime now;
    late AdPolicy p;
    final start = DateTime(2026, 1, 1, 12);

    setUp(() {
      now = start;
      p = AdPolicy(firstLaunch: start, clock: () => now);
    });

    test('no ads in the first 60 s of the first launch', () {
      for (var i = 0; i < 3; i++) {
        p.onRoundFinished();
      }
      expect(p.canShowInterstitial(adsRemoved: false), isFalse);
      expect(p.canShowAppOpen(adsRemoved: false), isFalse);
      now = start.add(const Duration(seconds: 61));
      expect(p.canShowInterstitial(adsRemoved: false), isTrue);
      expect(p.canShowAppOpen(adsRemoved: false), isTrue);
    });

    test('interstitial only every 3 rounds', () {
      now = start.add(const Duration(minutes: 5));
      p.onRoundFinished();
      p.onRoundFinished();
      expect(p.canShowInterstitial(adsRemoved: false), isFalse);
      p.onRoundFinished();
      expect(p.canShowInterstitial(adsRemoved: false), isTrue);
      p.onInterstitialShown();
      expect(p.roundsSinceInterstitial, 0);
    });

    test('120 s gap between any two full-screen ads', () {
      now = start.add(const Duration(minutes: 5));
      p.markFullScreen(); // e.g. a rewarded ad
      for (var i = 0; i < 3; i++) {
        p.onRoundFinished();
      }
      now = now.add(const Duration(seconds: 119));
      expect(p.canShowInterstitial(adsRemoved: false), isFalse);
      expect(p.canShowAppOpen(adsRemoved: false), isFalse);
      now = now.add(const Duration(seconds: 1));
      expect(p.canShowInterstitial(adsRemoved: false), isTrue);
      expect(p.canShowAppOpen(adsRemoved: false), isTrue);
    });

    test('remove ads disables interstitial and app open', () {
      now = start.add(const Duration(minutes: 5));
      for (var i = 0; i < 3; i++) {
        p.onRoundFinished();
      }
      expect(p.canShowInterstitial(adsRemoved: true), isFalse);
      expect(p.canShowAppOpen(adsRemoved: true), isFalse);
    });
  });

  group('levels and daily', () {
    test('level curve', () {
      expect(PlayerLevel.levelFor(0), 1);
      expect(PlayerLevel.levelFor(1999), 1);
      expect(PlayerLevel.levelFor(2000), 2);
      expect(PlayerLevel.levelFor(8000), 3);
      expect(PlayerLevel.levelFor(50000), 6);
      expect(PlayerLevel.progress(5000), closeTo(0.5, 1e-9));
    });

    test('daily key uses UTC and the seed is stable', () {
      final a = DateTime.utc(2026, 9, 28, 23, 59);
      expect(DailyChallenge.dayKey(a), '20260928');
      expect(
        DailyChallenge.seedFor('20260928'),
        DailyChallenge.seedFor('20260928'),
      );
      expect(
        DailyChallenge.seedFor('20260928'),
        isNot(DailyChallenge.seedFor('20260929')),
      );
    });
  });

  test('every English string has an Arabic translation', () {
    expect(AppStrings.missingKeys('ar'), isEmpty);
    expect(AppStrings.get('ar', 'level', {'n': 3}), 'المستوى 3');
  });

  group('GameController', () {
    late StorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = StorageService();
      await storage.init();
    });

    Direction anyMove(GameController c) =>
        Direction.values.firstWhere((d) => wouldMove(c, d));

    test('3 free undos, then more only via grant', () {
      final c = GameController(mode: GameModes.classic, storage: storage);
      for (var i = 0; i < 5; i++) {
        c.move(anyMove(c));
      }
      expect(c.undo(), isTrue);
      expect(c.undo(), isTrue);
      expect(c.undo(), isTrue);
      expect(c.undosLeft, 0);
      expect(c.undo(), isFalse);
      c.grantUndos();
      expect(c.undo(), isTrue);
    });

    test('daily challenge: same board for everyone, no undo', () {
      final day = DateTime.utc(2026, 9, 28);
      final a = GameController(
        mode: GameModes.daily,
        storage: storage,
        now: day,
      );
      SharedPreferences.setMockInitialValues({});
      final b = GameController(
        mode: GameModes.daily,
        storage: storage,
        now: day,
      );
      expect(a.board.toGrid(), b.board.toGrid());
      a.move(anyMove(a));
      expect(a.undoAllowed, isFalse);
    });

    test('saves and resumes a game', () {
      final c = GameController(mode: GameModes.classic, storage: storage);
      c.move(anyMove(c));
      final grid = c.board.toGrid();
      final resumed = GameController(mode: GameModes.classic, storage: storage);
      expect(resumed.board.toGrid(), grid);
      expect(resumed.score, c.score);
    });

    test('finishRound pays once, adds XP and clears the save', () {
      final c = GameController(mode: GameModes.classic, storage: storage);
      c.board = Board.fromValues([
        [1024, 512, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
      ], score: 12000);
      final r = c.finishRound(doubled: true)!;
      expect(r.coins, (120 + 50) * 2);
      expect(storage.coins, r.coins);
      expect(storage.xp, 12000);
      expect(r.newLevel, 3);
      expect(storage.isUnlocked(GameModes.big), isTrue);
      expect(storage.hasSavedGame(GameModes.classic.id), isFalse);
      expect(c.finishRound(), isNull);
    });

    test('continue after losing removes 4 tiles once', () {
      final c = GameController(mode: GameModes.classic, storage: storage);
      c.board = Board.fromValues([
        [2, 4, 2, 4],
        [4, 2, 4, 2],
        [2, 4, 2, 4],
        [4, 2, 4, 8],
      ]);
      c.gameOver = !c.board.canMove;
      expect(c.canContinue, isTrue);
      c.continueGame();
      expect(c.board.tiles.length, 12);
      expect(c.gameOver, isFalse);
      expect(c.canContinue, isFalse);
    });
  });
}

/// Whether [d] would move the controller's board (checked on a copy).
bool wouldMove(GameController c, Direction d) =>
    Board.fromJson(c.board.toJson()).move(d).moved;
