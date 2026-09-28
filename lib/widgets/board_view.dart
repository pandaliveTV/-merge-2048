import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/tile_themes.dart';
import '../game/board.dart';
import '../game/game_controller.dart';

const slideDuration = Duration(milliseconds: 110);
const _popDuration = Duration(milliseconds: 170);

enum _Appear { none, merged, spawned }

/// Renders the grid. Tiles keep their id while sliding, so an
/// [AnimatedPositioned] per tile gives the slide; merged tiles "pop" and
/// spawned tiles grow in once the slide has finished.
class BoardView extends StatefulWidget {
  final TileTheme theme;
  const BoardView({super.key, required this.theme});

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView> {
  int _seenSerial = -1;
  bool _showGhosts = false;
  Timer? _ghostTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = context.watch<GameController>();
    if (c.serial != _seenSerial) {
      _seenSerial = c.serial;
      _showGhosts = c.ghosts.isNotEmpty;
      _ghostTimer?.cancel();
      if (_showGhosts) {
        _ghostTimer = Timer(slideDuration, () {
          if (mounted) setState(() => _showGhosts = false);
        });
      }
    }
  }

  @override
  void dispose() {
    _ghostTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GameController>();
    final n = c.mode.size;
    final theme = widget.theme;
    return LayoutBuilder(
      builder: (context, box) {
        final side = box.biggest.shortestSide;
        final gap = side * (n <= 4 ? 0.028 : 0.022);
        final cell = (side - gap * (n + 1)) / n;
        final radius = cell * 0.12;
        double pos(int i) => gap + i * (cell + gap);

        Widget positioned(Tile t, _Appear appear) => AnimatedPositioned(
          key: ValueKey(t.id),
          duration: slideDuration,
          curve: Curves.easeOutCubic,
          left: pos(t.col),
          top: pos(t.row),
          width: cell,
          height: cell,
          child: _AppearAnimation(
            appear: appear,
            child: TileView(
              value: t.value,
              theme: theme,
              size: cell,
              radius: radius,
            ),
          ),
        );

        // Swipe directions are physical, so the board is always laid out LTR.
        return Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: side,
            height: side,
            child: Container(
              decoration: BoxDecoration(
                color: theme.board,
                borderRadius: BorderRadius.circular(radius * 1.4),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var r = 0; r < n; r++)
                    for (var col = 0; col < n; col++)
                      Positioned(
                        left: pos(col),
                        top: pos(r),
                        width: cell,
                        height: cell,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.emptyCell,
                            borderRadius: BorderRadius.circular(radius),
                          ),
                        ),
                      ),
                  if (_showGhosts)
                    for (final g in c.ghosts) positioned(g, _Appear.none),
                  for (final t in c.board.tiles)
                    positioned(
                      t,
                      c.mergedIds.contains(t.id)
                          ? _Appear.merged
                          : c.spawnedIds.contains(t.id)
                          ? _Appear.spawned
                          : _Appear.none,
                    ),
                  if (c.hint != null)
                    Positioned.fill(child: _HintArrow(direction: c.hint!)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Plays once when a tile widget is first created.
class _AppearAnimation extends StatelessWidget {
  final _Appear appear;
  final Widget child;
  const _AppearAnimation({required this.appear, required this.child});

  static const _slideFrac = 0.4;

  @override
  Widget build(BuildContext context) {
    // Only the first build's tween begin matters; later rebuilds keep end=1
    // so an existing tile never replays its animation.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: appear == _Appear.none ? 1.0 : 0.0, end: 1.0),
      duration: slideDuration + _popDuration,
      child: child,
      builder: (context, t, child) {
        if (t >= 1.0 || appear == _Appear.none) return child!;
        if (t < _slideFrac) return const SizedBox.shrink();
        final u = (t - _slideFrac) / (1 - _slideFrac);
        final scale = appear == _Appear.merged
            ? (u < 0.5 ? 0.7 + 0.5 * (u / 0.5) : 1.2 - 0.2 * ((u - 0.5) / 0.5))
            : Curves.easeOutBack.transform(u);
        return Transform.scale(scale: scale, child: child);
      },
    );
  }
}

class TileView extends StatelessWidget {
  final int value;
  final TileTheme theme;
  final double size;
  final double radius;

  const TileView({
    super.key,
    required this.value,
    required this.theme,
    required this.size,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final digits = '$value'.length;
    final factor = switch (digits) {
      1 || 2 => 0.46,
      3 => 0.38,
      4 => 0.3,
      _ => 0.24,
    };
    final color = theme.tileColor(value);
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: value >= 128
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.45),
                    blurRadius: size * 0.12,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            '$value',
            maxLines: 1,
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontSize: size * factor,
              fontWeight: FontWeight.w800,
              color: theme.textColor(value),
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _HintArrow extends StatelessWidget {
  final Direction direction;
  const _HintArrow({required this.direction});

  @override
  Widget build(BuildContext context) {
    final icon = switch (direction) {
      Direction.up => Icons.arrow_upward_rounded,
      Direction.down => Icons.arrow_downward_rounded,
      Direction.left => Icons.arrow_back_rounded,
      Direction.right => Icons.arrow_forward_rounded,
    };
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 300),
        builder: (context, t, _) => Opacity(
          opacity: t * 0.85,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 72, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
