import 'dart:math' as math;

import 'board.dart';

/// Suggests a move with a shallow expectimax search on plain value grids.
/// It never touches the board's RNG, so asking for a hint cannot change
/// the upcoming spawns (important for the daily challenge).
class HintEngine {
  final int size;
  HintEngine(this.size);

  /// Slides a row-major [grid]; returns null when nothing moves.
  List<int>? slide(List<int> grid, Direction d) {
    final n = size;
    final out = List<int>.filled(n * n, 0);
    var moved = false;
    for (var i = 0; i < n; i++) {
      final idx = <int>[
        for (var k = 0; k < n; k++)
          switch (d) {
            Direction.left => i * n + k,
            Direction.right => i * n + (n - 1 - k),
            Direction.up => k * n + i,
            Direction.down => (n - 1 - k) * n + i,
          },
      ];
      final values = [
        for (final j in idx)
          if (grid[j] != 0) grid[j],
      ];
      final merged = <int>[];
      for (var k = 0; k < values.length; k++) {
        if (k + 1 < values.length && values[k] == values[k + 1]) {
          merged.add(values[k] * 2);
          k++;
        } else {
          merged.add(values[k]);
        }
      }
      for (var k = 0; k < n; k++) {
        final v = k < merged.length ? merged[k] : 0;
        out[idx[k]] = v;
        if (grid[idx[k]] != v) moved = true;
      }
    }
    return moved ? out : null;
  }

  Direction? bestMove(List<int> grid) {
    Direction? best;
    var bestScore = double.negativeInfinity;
    for (final d in Direction.values) {
      final g = slide(grid, d);
      if (g == null) continue;
      final s = _chance(g, 1);
      if (s > bestScore) {
        bestScore = s;
        best = d;
      }
    }
    return best;
  }

  double _max(List<int> grid, int depth) {
    var best = double.negativeInfinity;
    for (final d in Direction.values) {
      final g = slide(grid, d);
      if (g == null) continue;
      final s = depth <= 0 ? evaluate(g) : _chance(g, depth - 1);
      if (s > best) best = s;
    }
    return best == double.negativeInfinity ? evaluate(grid) - 1e6 : best;
  }

  double _chance(List<int> grid, int depth) {
    final empty = [
      for (var i = 0; i < grid.length; i++)
        if (grid[i] == 0) i,
    ];
    if (empty.isEmpty) return _max(grid, depth);
    // Cap the branching factor on big boards.
    final step = math.max(1, empty.length ~/ 6);
    var total = 0.0;
    var count = 0;
    for (var k = 0; k < empty.length; k += step) {
      final i = empty[k];
      final g2 = [...grid]..[i] = 2;
      final g4 = [...grid]..[i] = 4;
      total += 0.9 * _max(g2, depth) + 0.1 * _max(g4, depth);
      count++;
    }
    return total / count;
  }

  /// Heuristic: free cells, monotonic rows/cols, smoothness, big tile in a corner.
  double evaluate(List<int> grid) {
    final n = size;
    var empty = 0;
    var mono = 0.0;
    var smooth = 0.0;
    var maxV = 0;
    double lg(int v) => v == 0 ? 0 : math.log(v) / math.ln2;
    for (var i = 0; i < grid.length; i++) {
      if (grid[i] == 0) empty++;
      if (grid[i] > maxV) maxV = grid[i];
    }
    for (var i = 0; i < n; i++) {
      var incR = 0.0, decR = 0.0, incC = 0.0, decC = 0.0;
      for (var k = 0; k + 1 < n; k++) {
        final a = lg(grid[i * n + k]), b = lg(grid[i * n + k + 1]);
        if (a > b) {
          decR += a - b;
        } else {
          incR += b - a;
        }
        final c = lg(grid[k * n + i]), d = lg(grid[(k + 1) * n + i]);
        if (c > d) {
          decC += c - d;
        } else {
          incC += d - c;
        }
        if (grid[i * n + k] != 0 && grid[i * n + k + 1] != 0) {
          smooth -= (a - b).abs();
        }
        if (grid[k * n + i] != 0 && grid[(k + 1) * n + i] != 0) {
          smooth -= (c - d).abs();
        }
      }
      mono -= math.min(incR, decR) + math.min(incC, decC);
    }
    final corners = [0, n - 1, n * (n - 1), n * n - 1];
    final cornerBonus = corners.any((i) => grid[i] == maxV) ? lg(maxV) : 0.0;
    return empty * 2.7 + mono * 1.0 + smooth * 0.1 + cornerBonus * 1.5;
  }
}
