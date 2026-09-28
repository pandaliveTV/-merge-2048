/// Pure frequency rules for full-screen ads, kept apart from the SDK so they
/// can be unit tested:
/// * nothing during the first 60 s after the very first launch
/// * at least 120 s between any two full-screen ads
/// * an interstitial only after every 3 finished rounds
/// * "Remove Ads" disables interstitial / app open (never rewarded)
class AdPolicy {
  static const minGap = Duration(seconds: 120);
  static const firstRunGrace = Duration(seconds: 60);
  static const roundsPerInterstitial = 3;

  final DateTime Function() now;
  final DateTime firstLaunch;

  AdPolicy({required this.firstLaunch, DateTime Function()? clock})
    : now = clock ?? DateTime.now;

  DateTime? lastFullScreen;
  int roundsSinceInterstitial = 0;

  bool get inGrace => now().difference(firstLaunch) < firstRunGrace;

  bool get gapOk =>
      lastFullScreen == null || now().difference(lastFullScreen!) >= minGap;

  void onRoundFinished() => roundsSinceInterstitial++;

  bool canShowInterstitial({required bool adsRemoved}) =>
      !adsRemoved &&
      !inGrace &&
      gapOk &&
      roundsSinceInterstitial >= roundsPerInterstitial;

  bool canShowAppOpen({required bool adsRemoved}) =>
      !adsRemoved && !inGrace && gapOk;

  /// Call whenever any full-screen ad (including rewarded) is shown/closed.
  void markFullScreen() => lastFullScreen = now();

  void onInterstitialShown() {
    roundsSinceInterstitial = 0;
    markFullScreen();
  }
}
