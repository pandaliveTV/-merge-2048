import 'package:flutter_test/flutter_test.dart';
import 'package:merge2048/game/board.dart';
import 'package:merge2048/game/hint.dart';
import 'package:merge2048/game/seeded_random.dart';

/// Values of [b] with the freshly spawned tile removed.
List<List<int>> withoutSpawn(Board b, MoveOutcome o) {
  final rows = b.toRows();
  for (final t in b.tiles) {
    if (t.id == o.spawnedId) rows[t.row][t.col] = 0;
  }
  return rows;
}

void main() {
  group('move', () {
    test('slides and merges left, one merge per tile', () {
      final b = Board.fromValues([
        [2, 2, 2, 2],
        [4, 0, 4, 8],
        [2, 4, 8, 16],
        [0, 0, 0, 2],
      ]);
      final o = b.move(Direction.left);
      expect(o.moved, isTrue);
      expect(o.gained, 4 + 4 + 8);
      expect(withoutSpawn(b, o), [
        [4, 4, 0, 0],
        [8, 8, 0, 0],
        [2, 4, 8, 16],
        [2, 0, 0, 0],
      ]);
      expect(b.score, 16);
      expect(b.tiles.length, 10); // 9 after the move + 1 spawn
    });

    test('merges towards the swipe edge', () {
      final b = Board.fromValues([
        [2, 2, 2, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
      ]);
      final o = b.move(Direction.right);
      expect(withoutSpawn(b, o)[0], [0, 0, 2, 4]);
    });

    test('up and down', () {
      final b = Board.fromValues([
        [2, 0, 0, 0],
        [2, 0, 0, 0],
        [4, 0, 0, 0],
        [4, 0, 0, 0],
      ]);
      var o = b.move(Direction.up);
      var rows = withoutSpawn(b, o);
      expect([for (final r in rows) r[0]], [4, 8, 0, 0]);

      final d = Board.fromValues([
        [8, 0, 0, 0],
        [0, 0, 0, 0],
        [8, 0, 0, 0],
        [2, 0, 0, 0],
      ]);
      o = d.move(Direction.down);
      rows = withoutSpawn(d, o);
      expect([for (final r in rows) r[0]], [0, 0, 16, 2]);
    });

    test('no-op move does not spawn', () {
      final b = Board.fromValues([
        [2, 4, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
      ]);
      final o = b.move(Direction.left);
      expect(o.moved, isFalse);
      expect(b.tiles.length, 2);
    });

    test('ghosts and merged ids describe the merge for animation', () {
      final b = Board.fromValues([
        [2, 2, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
      ]);
      final ids = b.tiles.map((t) => t.id).toSet();
      final o = b.move(Direction.left);
      expect(o.ghosts.map((g) => g.id).toSet(), ids);
      expect(o.ghosts.every((g) => g.row == 0 && g.col == 0), isTrue);
      expect(o.mergedIds.length, 1);
      expect(o.bestMerge, 4);
      final merged = b.tiles.firstWhere((t) => o.mergedIds.contains(t.id));
      expect(merged.value, 4);
    });

    test('works on 5x5 and 6x6', () {
      for (final n in [5, 6]) {
        final rows = List.generate(n, (_) => List.filled(n, 0));
        rows[0] = List.filled(n, 2);
        final b = Board.fromValues(rows);
        final o = b.move(Direction.left);
        final expected = List.filled(n, 0);
        for (var i = 0; i < n ~/ 2; i++) {
          expected[i] = 4;
        }
        if (n.isOdd) expected[n ~/ 2] = 2;
        expect(withoutSpawn(b, o)[0], expected);
      }
    });
  });

  test('canMove detects locked boards', () {
    final locked = Board.fromValues([
      [2, 4, 2, 4],
      [4, 2, 4, 2],
      [2, 4, 2, 4],
      [4, 2, 4, 2],
    ]);
    expect(locked.canMove, isFalse);
    final open = Board.fromValues([
      [2, 4, 2, 4],
      [4, 2, 4, 2],
      [2, 4, 2, 4],
      [4, 2, 4, 4],
    ]);
    expect(open.canMove, isTrue);
  });

  test('removeSmallest removes the 4 smallest tiles', () {
    final b = Board.fromValues([
      [2, 4, 8, 16],
      [32, 64, 128, 256],
      [2, 4, 8, 16],
      [32, 64, 128, 256],
    ]);
    b.removeSmallest(4);
    expect(b.tiles.length, 12);
    expect(b.tiles.map((t) => t.value).where((v) => v <= 4), isEmpty);
    expect(b.canMove, isTrue);
  });

  test('undo snapshot restores tiles, score and RNG', () {
    final b = Board.newGame(4, 42);
    final snap = b.snapshot();
    final gridBefore = b.toGrid();
    Direction.values.firstWhere((d) => b.move(d).moved);
    final after = b.toGrid();
    b.restore(snap);
    expect(b.toGrid(), gridBefore);
    expect(b.score, 0);
    // Replaying the same move gives the exact same spawn.
    Direction.values.firstWhere((d) => b.move(d).moved);
    expect(b.toGrid(), after);
  });

  test('json round trip', () {
    final b = Board.newGame(5, 7);
    b.move(Direction.left);
    b.move(Direction.up);
    final c = Board.fromJson(b.toJson());
    expect(c.toGrid(), b.toGrid());
    expect(c.score, b.score);
    expect(c.rng.state, b.rng.state);
    expect(c.nextId, b.nextId);
  });

  group('seeded random', () {
    test('same seed, same sequence', () {
      final a = SeededRandom(123), b = SeededRandom(123);
      for (var i = 0; i < 100; i++) {
        expect(a.nextUint32(), b.nextUint32());
      }
    });

    test('same seed gives the same daily board and spawns', () {
      final a = Board.newGame(4, 2026);
      final b = Board.newGame(4, 2026);
      expect(a.toGrid(), b.toGrid());
      for (final d in [Direction.left, Direction.up, Direction.right]) {
        a.move(d);
        b.move(d);
        expect(a.toGrid(), b.toGrid());
      }
    });

    test('values stay in range', () {
      final r = SeededRandom(99);
      for (var i = 0; i < 1000; i++) {
        final v = r.nextDouble();
        expect(v >= 0 && v < 1, isTrue);
        expect(r.nextInt(6), inInclusiveRange(0, 5));
      }
    });
  });

  group('hint engine', () {
    test('slide matches Board.move', () {
      final rows = [
        [2, 2, 4, 0],
        [0, 4, 4, 4],
        [8, 0, 8, 2],
        [2, 2, 2, 2],
      ];
      for (final d in Direction.values) {
        final b = Board.fromValues(rows);
        final o = b.move(d);
        final g = HintEngine(4).slide([for (final r in rows) ...r], d);
        expect(g, withoutSpawn(b, o).expand((r) => r).toList());
      }
    });

    test('suggests a legal move and null when stuck', () {
      final h = HintEngine(4);
      final grid = [2, 4, 2, 4, 4, 2, 4, 2, 2, 4, 2, 4, 4, 2, 4, 4];
      final d = h.bestMove(grid);
      expect(d, isNotNull);
      expect(h.slide(grid, d!), isNotNull);
      final stuck = [2, 4, 2, 4, 4, 2, 4, 2, 2, 4, 2, 4, 4, 2, 4, 2];
      expect(h.bestMove(stuck), isNull);
    });

    test('plays a full game on 6x6 quickly', () {
      final b = Board.newGame(6, 1);
      final h = HintEngine(6);
      final sw = Stopwatch()..start();
      for (var i = 0; i < 50 && b.canMove; i++) {
        b.move(h.bestMove(b.toGrid())!);
      }
      expect(sw.elapsedMilliseconds, lessThan(5000));
    });
  });
}
