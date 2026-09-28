import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/strings.dart';
import '../data/tile_themes.dart';
import '../services/audio_service.dart';
import '../services/storage_service.dart';
import '../widgets/common.dart';

/// Tile colour themes, bought with coins.
class ThemesScreen extends StatelessWidget {
  const ThemesScreen({super.key});

  Future<void> _onTap(BuildContext context, TileTheme t) async {
    final s = context.read<StorageService>();
    if (s.ownedThemes.contains(t.id)) {
      s.selectTheme(t.id);
      return;
    }
    if (s.coins < t.price) {
      showSnack(context, context.tr('notEnoughCoins'));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('theme_${t.id}')),
        content: Text(ctx.tr('useCoins', {'n': t.price})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.tr('buy')),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    if (s.spend(t.price)) {
      s.unlockTheme(t.id);
      context.read<AudioService>().play(Sfx.coin);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<StorageService>();
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('themes')),
        actions: const [CoinBadge(), SizedBox(width: 12)],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 240,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.8,
        ),
        itemCount: TileThemes.all.length,
        itemBuilder: (context, i) {
          final t = TileThemes.all[i];
          final owned = s.ownedThemes.contains(t.id);
          final selected = s.tileTheme == t.id;
          return _ThemeCard(
            theme: t,
            status: selected
                ? context.tr('selected')
                : owned
                ? context.tr('owned')
                : '${t.price}',
            locked: !owned,
            selected: selected,
            onTap: () => _onTap(context, t),
          );
        },
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final TileTheme theme;
  final String status;
  final bool locked;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.theme,
    required this.status,
    required this.locked,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const sample = [2, 8, 32, 128, 512, 2048];
    return Material(
      color: theme.background,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected ? theme.tileColor(2048) : theme.board,
          width: selected ? 4 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.board,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: GridView.count(
                    crossAxisCount: 3,
                    mainAxisSpacing: 5,
                    crossAxisSpacing: 5,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (final v in sample)
                        Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: theme.tileColor(v),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: FittedBox(
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Text(
                                '$v',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: theme.textColor(v),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('theme_${theme.id}'),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: theme.board,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (locked)
                    const Icon(
                      Icons.monetization_on,
                      color: Colors.amber,
                      size: 18,
                    ),
                  if (selected)
                    Icon(
                      Icons.check_circle,
                      color: theme.tileColor(2048),
                      size: 18,
                    ),
                  const SizedBox(width: 4),
                  Text(
                    status,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: theme.board,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
