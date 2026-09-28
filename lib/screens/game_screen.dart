import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/game_modes.dart';
import '../data/strings.dart';
import '../game/board.dart';
import '../game/game_controller.dart';
import '../services/ad_service.dart';
import '../services/audio_service.dart';
import '../services/storage_service.dart';
import '../widgets/board_view.dart';
import '../widgets/common.dart';

/// Gameplay screen. No banner here by design.
class GameScreen extends StatefulWidget {
  final GameMode mode;
  const GameScreen({super.key, required this.mode});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameController _c;
  late final AudioService _audio;
  late final AdService _ads;
  Offset _drag = Offset.zero;
  bool _swiped = false;

  @override
  void initState() {
    super.initState();
    _c = GameController(
      mode: widget.mode,
      storage: context.read<StorageService>(),
    );
    _audio = context.read<AudioService>();
    _ads = context.read<AdService>();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // ---------------- Input ----------------
  void _onPanUpdate(DragUpdateDetails d) {
    if (_swiped) return;
    _drag += d.delta;
    if (_drag.distance < 24) return;
    _swiped = true;
    final dir = _drag.dx.abs() > _drag.dy.abs()
        ? (_drag.dx > 0 ? Direction.right : Direction.left)
        : (_drag.dy > 0 ? Direction.down : Direction.up);
    _move(dir);
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final dir = switch (e.logicalKey) {
      LogicalKeyboardKey.arrowUp => Direction.up,
      LogicalKeyboardKey.arrowDown => Direction.down,
      LogicalKeyboardKey.arrowLeft => Direction.left,
      LogicalKeyboardKey.arrowRight => Direction.right,
      _ => null,
    };
    if (dir == null) return KeyEventResult.ignored;
    _move(dir);
    return KeyEventResult.handled;
  }

  void _move(Direction d) {
    final out = _c.move(d);
    if (!out.moved) return;
    if (_c.gameOver) {
      _audio.play(Sfx.gameOver);
      _audio.medium();
    } else if (_c.showWin) {
      _audio.play(Sfx.win);
      _audio.medium();
    } else if (out.mergedIds.isNotEmpty) {
      _audio.play(Sfx.merge);
      out.bestMerge >= 256 ? _audio.medium() : _audio.light();
    } else {
      _audio.play(Sfx.move);
    }
  }

  // ---------------- Round results ----------------
  void _handleRound(RoundResult? r) {
    if (r == null) return;
    _ads.onRoundFinished();
    final parts = <String>[];
    if (r.coins > 0) parts.add(context.tr('coinsEarned', {'n': r.coins}));
    if (r.dailyBonus > 0) {
      parts.add(context.tr('dailyBonus', {'n': r.dailyBonus}));
    }
    final level = r.newLevel;
    if (level != null) {
      parts.add(context.tr('levelUp', {'n': level}));
      for (final m in GameModes.progression) {
        if (m.unlockLevel == level) {
          parts.add(context.tr('unlocked', {'mode': m.sizeLabel}));
        }
      }
    }
    if (r.coins + r.dailyBonus > 0) _audio.play(Sfx.coin);
    if (parts.isNotEmpty) showSnack(context, parts.join('  •  '));
  }

  Future<void> _newGame({bool confirm = true}) async {
    if (confirm && _c.score > 0 && !_c.gameOver) {
      final ok = await _confirm(context.tr('newGameConfirm'));
      if (!ok || !mounted) return;
    }
    _handleRound(_c.newGame());
    _ads.showInterstitialIfDue();
  }

  /// Leaving mid-game keeps the saved board; leaving a lost game ends the
  /// round (coins + XP) and is a natural break for an interstitial.
  void _onPop(bool didPop, Object? _) {
    if (!didPop || !_c.gameOver || _c.coinsClaimed) return;
    _handleRound(_c.finishRound());
    _ads.showInterstitialIfDue();
  }

  void _leave() => Navigator.of(context).maybePop();

  // ---------------- Undo / hint / continue ----------------
  Future<void> _undo() async {
    if (_c.undosLeft > 0) {
      if (_c.undo()) _audio.light();
      return;
    }
    final ok = await _confirm(
      context.tr('undoMoreBody', {'n': GameController.undosPerAd}),
      title: context.tr('undoMoreTitle'),
      yes: context.tr('watchAd'),
    );
    if (!ok || !mounted) return;
    if (await watchRewarded(context)) _c.grantUndos();
  }

  Future<void> _hint() async {
    final storage = context.read<StorageService>();
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('hintTitle')),
        content: Text(ctx.tr('hintBody', {'n': GameController.hintCost})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.tr('cancel')),
          ),
          TextButton.icon(
            icon: const Icon(Icons.monetization_on, color: Colors.amber),
            onPressed: storage.coins >= GameController.hintCost
                ? () => Navigator.pop(ctx, 'coins')
                : null,
            label: Text(ctx.tr('useCoins', {'n': GameController.hintCost})),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.ondemand_video),
            onPressed: () => Navigator.pop(ctx, 'ad'),
            label: Text(ctx.tr('watchAd')),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    final paid = choice == 'coins'
        ? storage.spend(GameController.hintCost)
        : await watchRewarded(context);
    if (!paid || !mounted) return;
    final dir = _c.computeHint();
    showSnack(
      context,
      dir == null
          ? context.tr('noHint')
          : context.tr('hintSwipe', {'dir': context.tr('dir_${dir.name}')}),
    );
  }

  Future<void> _continue() async {
    if (await watchRewarded(context)) _c.continueGame();
  }

  Future<void> _doubleCoins() async {
    if (await watchRewarded(context)) {
      if (!mounted) return;
      _handleRound(_c.finishRound(doubled: true));
    }
  }

  Future<bool> _confirm(String body, {String? title, String? yes}) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: title == null ? null : Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(yes ?? ctx.tr('yes')),
          ),
        ],
      ),
    );
    return r ?? false;
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final theme = currentTheme(context);
    return ChangeNotifierProvider.value(
      value: _c,
      child: Consumer<GameController>(
        builder: (context, c, _) => PopScope(
          onPopInvokedWithResult: _onPop,
          child: Scaffold(
            appBar: AppBar(
              leading: BackButton(onPressed: _leave),
              title: Text(
                widget.mode.daily
                    ? context.tr('daily')
                    : '${context.tr(widget.mode.id)} ${widget.mode.sizeLabel}',
              ),
              actions: const [CoinBadge(), SizedBox(width: 12)],
            ),
            body: Focus(
              autofocus: true,
              onKeyEvent: _onKey,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) {
                  _drag = Offset.zero;
                  _swiped = false;
                },
                onPanUpdate: _onPanUpdate,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            StatBox(label: context.tr('score'), value: c.score),
                            const SizedBox(width: 12),
                            StatBox(label: context.tr('best'), value: c.best),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _ActionBar(
                          controller: c,
                          onNew: _newGame,
                          onUndo: _undo,
                          onHint: _hint,
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: BoardView(theme: theme),
                                  ),
                                  if (c.gameOver)
                                    Positioned.fill(
                                      child: _GameOverPanel(
                                        controller: c,
                                        onContinue: _continue,
                                        onDouble: _doubleCoins,
                                        onNewGame: () =>
                                            _newGame(confirm: false),
                                        onHome: _leave,
                                      ),
                                    )
                                  else if (c.showWin)
                                    Positioned.fill(
                                      child: _WinPanel(
                                        onKeepGoing: c.keepGoing,
                                        onNewGame: () =>
                                            _newGame(confirm: false),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            widget.mode.daily
                                ? context.tr('dailyRules')
                                : context.tr('swipeToPlay'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final GameController controller;
  final VoidCallback onNew;
  final VoidCallback onUndo;
  final VoidCallback onHint;

  const _ActionBar({
    required this.controller,
    required this.onNew,
    required this.onUndo,
    required this.onHint,
  });

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final busy = c.gameOver || c.showWin;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RoundAction(
          icon: Icons.refresh_rounded,
          label: context.tr('newGame'),
          onPressed: onNew,
        ),
        if (!c.mode.daily) ...[
          const SizedBox(width: 12),
          _RoundAction(
            icon: Icons.undo_rounded,
            label: context.tr('undo'),
            badge: c.undosLeft > 0 ? '${c.undosLeft}' : null,
            badgeIcon: c.undosLeft > 0 ? null : Icons.ondemand_video,
            onPressed: c.undoAllowed ? onUndo : null,
          ),
        ],
        const SizedBox(width: 12),
        _RoundAction(
          icon: Icons.lightbulb_rounded,
          label: context.tr('hint'),
          onPressed: busy ? null : onHint,
        ),
      ],
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final IconData? badgeIcon;
  final VoidCallback? onPressed;

  const _RoundAction({
    required this.icon,
    required this.label,
    this.badge,
    this.badgeIcon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = currentTheme(context);
    final hasBadge = badge != null || badgeIcon != null;
    return Tooltip(
      message: label,
      child: Badge(
        isLabelVisible: hasBadge,
        backgroundColor: theme.tileColor(2048),
        textColor: theme.textColor(2048),
        label: badgeIcon != null
            ? Icon(badgeIcon, size: 12, color: theme.textColor(2048))
            : Text(badge ?? ''),
        child: IconButton.filled(
          style: IconButton.styleFrom(
            backgroundColor: theme.board,
            foregroundColor: theme.lightText,
            fixedSize: const Size(56, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: onPressed,
          icon: Icon(icon),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final List<Widget> children;
  const _Panel({required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = currentTheme(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: Container(
        decoration: BoxDecoration(
          color: theme.background.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}

class _GameOverPanel extends StatelessWidget {
  final GameController controller;
  final VoidCallback onContinue;
  final VoidCallback onDouble;
  final VoidCallback onNewGame;
  final VoidCallback onHome;

  const _GameOverPanel({
    required this.controller,
    required this.onContinue,
    required this.onDouble,
    required this.onNewGame,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final theme = currentTheme(context);
    return _Panel(
      children: [
        Text(
          context.tr('gameOver'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: theme.board,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${context.tr('score')}: ${c.score}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
            const SizedBox(width: 4),
            Text(
              c.coinsClaimed
                  ? context.tr('coinsClaimed')
                  : context.tr('coinsEarned', {'n': c.roundCoins}),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (c.canContinue) ...[
          FilledButton.icon(
            onPressed: onContinue,
            icon: const Icon(Icons.ondemand_video),
            label: Text(context.tr('continueAd')),
          ),
          const SizedBox(height: 8),
        ],
        if (!c.coinsClaimed && c.roundCoins > 0) ...[
          FilledButton.tonalIcon(
            onPressed: onDouble,
            icon: const Icon(Icons.ondemand_video),
            label: Text(context.tr('doubleCoins')),
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: onNewGame,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.tr('newGame')),
            ),
            OutlinedButton.icon(
              onPressed: onHome,
              icon: const Icon(Icons.home_rounded),
              label: Text(context.tr('home')),
            ),
          ],
        ),
      ],
    );
  }
}

class _WinPanel extends StatelessWidget {
  final VoidCallback onKeepGoing;
  final VoidCallback onNewGame;

  const _WinPanel({required this.onKeepGoing, required this.onNewGame});

  @override
  Widget build(BuildContext context) {
    final theme = currentTheme(context);
    return _Panel(
      children: [
        const Icon(Icons.emoji_events_rounded, size: 56, color: Colors.amber),
        Text(
          context.tr('youWin'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: theme.board,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onKeepGoing,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(context.tr('keepGoing')),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onNewGame,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(context.tr('newGame')),
        ),
      ],
    );
  }
}
