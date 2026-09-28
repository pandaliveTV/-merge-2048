import 'seeded_random.dart';

enum Direction { up, down, left, right }

/// A single numbered tile. [id] is stable while the tile slides so the UI
/// can animate it; a merge produces a brand-new id.
class Tile {
  final int id;
  final int value;
  final int row;
  final int col;

  const Tile(this.id, this.value, this.row, this.col);

  Tile at(int r, int c) => Tile(id, value, r, c);

  Map<String, int> toJson() => {'i': id, 'v': value, 'r': row, 'c': col};

  factory Tile.fromJson(Map<String, dynamic> j) =>
      Tile(j['i'] as int, j['v'] as int, j['r'] as int, j['c'] as int);

  @override
  String toString() => 'Tile#$id($value @ $row,$col)';
}

/// Result of a swipe, used by the UI for animation and feedback.
class MoveOutcome {
  final bool moved;
  final int gained;

  /// Tiles consumed by a merge, positioned at the cell they merged into.
  /// They are drawn sliding in and then removed.
  final List<Tile> ghosts;

  /// Ids of tiles created by a merge (they "pop").
  final Set<int> mergedIds;

  /// Id of the freshly spawned tile, if any.
  final int? spawnedId;

  /// Highest value produced by a merge in this move (0 if none).
  final int bestMerge;

  const MoveOutcome({
    required this.moved,
    this.gained = 0,
    this.ghosts = const [],
    this.mergedIds = const {},
    this.spawnedId,
    this.bestMerge = 0,
  });

  static const none = MoveOutcome(moved: false);
}

/// Immutable copy of a board, used for Undo.
class BoardSnapshot {
  final List<Tile> tiles;
  final int score;
  final int rngState;
  final int nextId;

  const BoardSnapshot(this.tiles, this.score, this.rngState, this.nextId);
}

/// Pure 2048 rules, independent from Flutter.
class Board {
  final int size;
  List<Tile> tiles;
  int score;
  int nextId;
  final SeededRandom rng;

  Board._(this.size, this.tiles, this.score, this.nextId, this.rng);

  /// Fresh board with two starting tiles.
  factory Board.newGame(int size, int seed) {
    final b = Board._(size, [], 0, 1, SeededRandom(seed));
    b.spawn();
    b.spawn();
    return b;
  }

  /// Board with explicit content (tests, restoring).
  factory Board.fromValues(
    List<List<int>> rows, {
    int seed = 1,
    int score = 0,
  }) {
    final size = rows.length;
    final tiles = <Tile>[];
    var id = 1;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (rows[r][c] != 0) tiles.add(Tile(id++, rows[r][c], r, c));
      }
    }
    return Board._(size, tiles, score, id, SeededRandom(seed));
  }

  int get maxTile => tiles.fold(0, (m, t) => t.value > m ? t.value : m);

  /// Row-major grid of values (0 = empty).
  List<int> toGrid() {
    final g = List<int>.filled(size * size, 0);
    for (final t in tiles) {
      g[t.row * size + t.col] = t.value;
    }
    return g;
  }

  List<List<int>> toRows() {
    final g = toGrid();
    return [for (var r = 0; r < size; r++) g.sublist(r * size, (r + 1) * size)];
  }

  List<(int, int)> get emptyCells {
    final g = toGrid();
    return [
      for (var i = 0; i < g.length; i++)
        if (g[i] == 0) (i ~/ size, i % size),
    ];
  }

  /// Adds a 2 (90%) or 4 (10%) on a random empty cell.
  Tile? spawn() {
    final empty = emptyCells;
    if (empty.isEmpty) return null;
    final (r, c) = empty[rng.nextInt(empty.length)];
    final value = rng.nextDouble() < 0.9 ? 2 : 4;
    final t = Tile(nextId++, value, r, c);
    tiles.add(t);
    return t;
  }

  /// Cells of line [i] ordered from the edge the tiles slide towards.
  List<(int, int)> _line(Direction d, int i) {
    final n = size;
    switch (d) {
      case Direction.left:
        return [for (var c = 0; c < n; c++) (i, c)];
      case Direction.right:
        return [for (var c = n - 1; c >= 0; c--) (i, c)];
      case Direction.up:
        return [for (var r = 0; r < n; r++) (r, i)];
      case Direction.down:
        return [for (var r = n - 1; r >= 0; r--) (r, i)];
    }
  }

  /// Slides and merges; spawns a new tile when anything moved.
  MoveOutcome move(Direction d) {
    final byCell = <int, Tile>{for (final t in tiles) t.row * size + t.col: t};
    final result = <Tile>[];
    final ghosts = <Tile>[];
    final merged = <int>{};
    var gained = 0;
    var bestMerge = 0;
    var moved = false;

    for (var i = 0; i < size; i++) {
      final cells = _line(d, i);
      final out = <Tile>[];
      var lastMergeable = false;
      for (final (r, c) in cells) {
        final t = byCell[r * size + c];
        if (t == null) continue;
        if (lastMergeable && out.last.value == t.value) {
          final prev = out.removeLast();
          final (tr, tc) = cells[out.length];
          ghosts
            ..add(prev.at(tr, tc))
            ..add(t.at(tr, tc));
          final m = Tile(nextId++, t.value * 2, tr, tc);
          out.add(m);
          merged.add(m.id);
          gained += m.value;
          if (m.value > bestMerge) bestMerge = m.value;
          lastMergeable = false;
          moved = true;
        } else {
          final (tr, tc) = cells[out.length];
          if (tr != t.row || tc != t.col) moved = true;
          out.add(t.at(tr, tc));
          lastMergeable = true;
        }
      }
      result.addAll(out);
    }

    if (!moved) return MoveOutcome.none;
    tiles = result;
    score += gained;
    final spawned = spawn();
    return MoveOutcome(
      moved: true,
      gained: gained,
      ghosts: ghosts,
      mergedIds: merged,
      spawnedId: spawned?.id,
      bestMerge: bestMerge,
    );
  }

  /// True while at least one swipe would change the board.
  bool get canMove {
    if (tiles.length < size * size) return true;
    final g = toGrid();
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final v = g[r * size + c];
        if (c + 1 < size && g[r * size + c + 1] == v) return true;
        if (r + 1 < size && g[(r + 1) * size + c] == v) return true;
      }
    }
    return false;
  }

  /// Removes the [n] smallest tiles ("Continue" after losing).
  /// Returns the removed tiles.
  List<Tile> removeSmallest(int n) {
    final sorted = [...tiles]
      ..sort((a, b) {
        final byValue = a.value.compareTo(b.value);
        return byValue != 0 ? byValue : a.id.compareTo(b.id);
      });
    final removed = sorted.take(n).toList();
    final ids = removed.map((t) => t.id).toSet();
    tiles = tiles.where((t) => !ids.contains(t.id)).toList();
    return removed;
  }

  BoardSnapshot snapshot() =>
      BoardSnapshot(List.unmodifiable(tiles), score, rng.state, nextId);

  void restore(BoardSnapshot s) {
    tiles = [...s.tiles];
    score = s.score;
    rng.state = s.rngState;
    nextId = s.nextId;
  }

  Map<String, dynamic> toJson() => {
    'size': size,
    'score': score,
    'nextId': nextId,
    'rng': rng.state,
    'tiles': [for (final t in tiles) t.toJson()],
  };

  factory Board.fromJson(Map<String, dynamic> j) {
    final rng = SeededRandom(0)..state = j['rng'] as int;
    return Board._(
      j['size'] as int,
      [
        for (final t in (j['tiles'] as List))
          Tile.fromJson(Map<String, dynamic>.from(t as Map)),
      ],
      j['score'] as int,
      j['nextId'] as int,
      rng,
    );
  }
}
