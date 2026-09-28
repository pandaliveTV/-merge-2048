import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/strings.dart';
import '../data/tile_themes.dart';
import '../services/ad_service.dart';
import '../services/storage_service.dart';

// TODO(EliteP): replace with the real privacy policy URL before publishing.
const privacyPolicyUrl = 'https://elitep.com/privacy';
const appVersion = '1.0.0';

TileTheme currentTheme(BuildContext context) =>
    TileThemes.byId(context.watch<StorageService>().tileTheme);

Future<void> openPrivacyPolicy(BuildContext context) {
  context.read<AdService>().skipNextAppOpen();
  return launchUrl(
    Uri.parse(privacyPolicyUrl),
    mode: LaunchMode.externalApplication,
  );
}

void showSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
}

class CoinBadge extends StatelessWidget {
  const CoinBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final coins = context.watch<StorageService>().coins;
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
          const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
          const SizedBox(width: 6),
          Text(
            '$coins',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class BigButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? foreground;

  const BigButton(
    this.label, {
    super.key,
    required this.icon,
    this.onPressed,
    this.color,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: foreground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
        ),
      ),
    );
  }
}

/// Small "2048" logo made of tiles, drawn with the current theme.
class LogoTiles extends StatelessWidget {
  final double size;
  const LogoTiles({super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final theme = currentTheme(context);
    const labels = ['2', '0', '4', '8'];
    const colorValues = [64, 256, 1024, 2048];
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 4; i++)
            Container(
              width: size,
              height: size,
              margin: EdgeInsets.all(size * 0.05),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.tileColor(colorValues[i]),
                borderRadius: BorderRadius.circular(size * 0.18),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: size * 0.6,
                  fontWeight: FontWeight.w900,
                  color: theme.textColor(colorValues[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Banner shown only on the Home and mode-select screens (never in game).
/// Waits for consent/SDK init and for the first-launch grace period.
class BannerSlot extends StatefulWidget {
  const BannerSlot({super.key});

  @override
  State<BannerSlot> createState() => _BannerSlotState();
}

class _BannerSlotState extends State<BannerSlot> {
  BannerAd? _ad;
  bool _loaded = false;
  Timer? _graceTimer;
  late final AdService _ads;

  @override
  void initState() {
    super.initState();
    _ads = context.read<AdService>();
    _ads.ready.addListener(_tryLoad);
    _tryLoad();
  }

  void _tryLoad() {
    if (_ad != null || !mounted || !_ads.bannersAllowed) return;
    final wait = _ads.graceRemaining;
    if (wait > Duration.zero) {
      _graceTimer?.cancel();
      _graceTimer = Timer(wait + const Duration(seconds: 1), _tryLoad);
      return;
    }
    _ad = _ads.createBanner(() {
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  void dispose() {
    _ads.ready.removeListener(_tryLoad);
    _graceTimer?.cancel();
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final removed = context.watch<StorageService>().adsRemoved;
    final ad = _ad;
    if (removed || !_loaded || ad == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}

/// Rounded info box ("Score 1234").
class StatBox extends StatelessWidget {
  final String label;
  final int value;
  const StatBox({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = currentTheme(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 88),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: theme.board,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.lightText.withValues(alpha: 0.8),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            transitionBuilder: (child, a) =>
                ScaleTransition(scale: a, child: child),
            child: Text(
              '$value',
              key: ValueKey(value),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: theme.lightText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Asks "Watch an ad?" and runs the rewarded flow. Returns true if earned.
Future<bool> watchRewarded(BuildContext context) async {
  final ads = context.read<AdService>();
  if (!ads.rewardedAvailable) {
    showSnack(context, context.tr('noAd'));
    return false;
  }
  return ads.showRewarded();
}
