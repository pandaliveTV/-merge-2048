import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/game_modes.dart';
import '../data/strings.dart';
import '../services/storage_service.dart';
import '../widgets/common.dart';
import 'game_screen.dart';

/// Board / level selection. 5×5 and 6×6 unlock with the player level.
class ModeSelectScreen extends StatelessWidget {
  const ModeSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<StorageService>();
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('chooseMode')),
        actions: const [CoinBadge(), SizedBox(width: 12)],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final m in GameModes.progression)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _ModeCard(
                      mode: m,
                      unlocked: s.isUnlocked(m),
                      best: s.best(m.id),
                      hasSave: s.hasSavedGame(m.id),
                    ),
                  ),
              ],
            ),
          ),
          const BannerSlot(),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final GameMode mode;
  final bool unlocked;
  final int best;
  final bool hasSave;

  const _ModeCard({
    required this.mode,
    required this.unlocked,
    required this.best,
    required this.hasSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = currentTheme(context);
    final accent = theme.tileColor(switch (mode.size) {
      4 => 128,
      5 => 512,
      _ => 2048,
    });
    final fg = theme.textColor(switch (mode.size) {
      4 => 128,
      5 => 512,
      _ => 2048,
    });
    return Opacity(
      opacity: unlocked ? 1 : 0.55,
      child: Material(
        color: accent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: unlocked
              ? () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => GameScreen(mode: mode)),
                )
              : () => showSnack(
                  context,
                  context.tr('locked', {'n': mode.unlockLevel}),
                ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                _MiniGrid(size: mode.size, color: fg),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${context.tr(mode.id)} ${mode.sizeLabel}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: fg,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        unlocked
                            ? '${context.tr('best')}: $best'
                            : context.tr('locked', {'n': mode.unlockLevel}),
                        style: TextStyle(color: fg.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                ),
                Icon(
                  !unlocked
                      ? Icons.lock_rounded
                      : hasSave
                      ? Icons.play_circle_fill_rounded
                      : Icons.chevron_right_rounded,
                  color: fg,
                  size: 32,
                ),
                if (unlocked && hasSave)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 4),
                    child: Text(
                      context.tr('resume'),
                      style: TextStyle(color: fg, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniGrid extends StatelessWidget {
  final int size;
  final Color color;
  const _MiniGrid({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    const side = 54.0;
    final cell = side / size;
    return SizedBox(
      width: side,
      height: side,
      child: Wrap(
        children: [
          for (var i = 0; i < size * size; i++)
            Container(
              width: cell,
              height: cell,
              padding: const EdgeInsets.all(1.5),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
