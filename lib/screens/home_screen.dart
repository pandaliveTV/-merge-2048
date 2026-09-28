import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/game_modes.dart';
import '../data/strings.dart';
import '../services/storage_service.dart';
import '../widgets/common.dart';
import 'game_screen.dart';
import 'mode_select_screen.dart';
import 'settings_screen.dart';
import 'themes_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final s = context.watch<StorageService>();
    final theme = currentTheme(context);
    final scheme = Theme.of(context).colorScheme;
    final today = DailyChallenge.dayKey();
    final dailyBest = s.dailyBest(today);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  _LevelBadge(xp: s.xp),
                  const Spacer(),
                  const CoinBadge(),
                  IconButton(
                    tooltip: context.tr('settings'),
                    icon: const Icon(Icons.settings),
                    onPressed: () => _push(context, const SettingsScreen()),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const FittedBox(child: LogoTiles(size: 64)),
                      const SizedBox(height: 12),
                      Text(
                        context.tr('appName'),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: theme.board,
                        ),
                      ),
                      const SizedBox(height: 40),
                      BigButton(
                        context.tr('play'),
                        icon: Icons.play_arrow_rounded,
                        color: theme.tileColor(64),
                        foreground: theme.textColor(64),
                        onPressed: () =>
                            _push(context, const ModeSelectScreen()),
                      ),
                      const SizedBox(height: 14),
                      BigButton(
                        context.tr('daily'),
                        icon: Icons.today_rounded,
                        color: theme.tileColor(2048),
                        foreground: theme.textColor(2048),
                        onPressed: () => _push(
                          context,
                          const GameScreen(mode: GameModes.daily),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        dailyBest > 0
                            ? context.tr('dailyDone', {'n': dailyBest})
                            : context.tr('dailySub'),
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 14),
                      BigButton(
                        context.tr('themes'),
                        icon: Icons.palette_rounded,
                        color: scheme.secondaryContainer,
                        foreground: scheme.onSecondaryContainer,
                        onPressed: () => _push(context, const ThemesScreen()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const BannerSlot(),
          ],
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  final int xp;
  const _LevelBadge({required this.xp});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Colors.orange, size: 20),
          const SizedBox(width: 6),
          Text(
            context.tr('level', {'n': PlayerLevel.levelFor(xp)}),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            child: LinearProgressIndicator(
              value: PlayerLevel.progress(xp),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}
