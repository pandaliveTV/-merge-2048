import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_policy.dart';
import 'storage_service.dart';

/// ===================== AdMob unit IDs =====================
/// These are Google's official TEST ids, safe to use while developing.
/// Before publishing, set [useTestAds] to false and fill the `_elitep*`
/// constants with the EliteP ad unit ids from the AdMob console.
/// Also replace the App ID in android/app/src/main/AndroidManifest.xml.
class AdIds {
  static const useTestAds = true;

  // TODO(EliteP): paste the real ad unit ids here.
  static const _elitepBanner = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const _elitepInterstitial = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const _elitepRewarded = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const _elitepAppOpen = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';

  static const banner = useTestAds
      ? 'ca-app-pub-3940256099942544/6300978111'
      : _elitepBanner;
  static const interstitial = useTestAds
      ? 'ca-app-pub-3940256099942544/1033173712'
      : _elitepInterstitial;
  static const rewarded = useTestAds
      ? 'ca-app-pub-3940256099942544/5224354917'
      : _elitepRewarded;
  static const appOpen = useTestAds
      ? 'ca-app-pub-3940256099942544/9257395921'
      : _elitepAppOpen;
}

/// Single place for all ad logic. Frequency rules live in [AdPolicy]:
/// * banner only on Home and mode-select screens (see BannerSlot)
/// * interstitial after every 3 rounds, ≥120 s between full-screen ads
/// * rewarded always player-initiated (hint / undo / continue / x2 coins)
/// * app open when returning from background, same 120 s gap
/// * nothing at all in the first 60 s after the first launch
/// * UMP (GDPR) consent is gathered before any ad request
/// * "Remove Ads" disables banner / interstitial / app open only
class AdService {
  final StorageService storage;
  late final AdPolicy policy;

  AdService(this.storage) {
    policy = AdPolicy(
      firstLaunch: DateTime.fromMillisecondsSinceEpoch(storage.firstLaunch),
    );
  }

  /// True once consent is resolved and the SDK is initialised.
  final ready = ValueNotifier<bool>(false);

  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  AppOpenAd? _appOpen;
  bool _showingFullScreen = false;
  bool _skipNextAppOpen = false;
  StreamSubscription<AppState>? _appStateSub;

  bool get _ready => ready.value;

  /// Time left before the first-launch grace period ends.
  Duration get graceRemaining {
    final elapsed = DateTime.now().difference(policy.firstLaunch);
    final left = AdPolicy.firstRunGrace - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  bool get bannersAllowed => _ready && !storage.adsRemoved;

  /// Gathers GDPR consent (UMP) first, then initialises the SDK.
  Future<void> init() async {
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => ConsentForm.loadAndShowConsentFormIfRequired((_) {
        if (!completer.isCompleted) completer.complete();
      }),
      (_) {
        if (!completer.isCompleted) completer.complete();
      },
    );
    await completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {},
    );
    await _startIfAllowed();
  }

  Future<void> _startIfAllowed() async {
    if (_ready) return;
    if (!await ConsentInformation.instance.canRequestAds()) return;
    await MobileAds.instance.initialize();
    ready.value = true;
    _loadInterstitial();
    _loadRewarded();
    _loadAppOpen();
    AppStateEventNotifier.startListening();
    _appStateSub = AppStateEventNotifier.appStateStream.listen((s) {
      if (s == AppState.foreground) _showAppOpen();
    });
  }

  /// Whether the "Ad privacy choices" entry must be shown in Settings.
  Future<bool> privacyOptionsRequired() async {
    try {
      return await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  Future<void> showPrivacyOptions() async {
    _skipNextAppOpen = true;
    await ConsentForm.showPrivacyOptionsForm((_) => _startIfAllowed());
  }

  /// Call before leaving the app on purpose (browser, store) so returning
  /// does not trigger an App Open ad.
  void skipNextAppOpen() => _skipNextAppOpen = true;

  void dispose() {
    _appStateSub?.cancel();
    ready.dispose();
  }

  // ---------------- Banner ----------------
  BannerAd? createBanner(VoidCallback onLoaded) {
    if (!bannersAllowed || policy.inGrace) return null;
    return BannerAd(
      adUnitId: AdIds.banner,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded(),
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    )..load();
  }

  // ---------------- Interstitial ----------------
  void _loadInterstitial() {
    if (storage.adsRemoved) return;
    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) => _interstitial = null,
      ),
    );
  }

  /// Call once per finished round (game over).
  void onRoundFinished() => policy.onRoundFinished();

  /// Call at a natural break (leaving the game-over panel). Shows an
  /// interstitial only when every rule allows it.
  void showInterstitialIfDue() {
    final ad = _interstitial;
    if (!_ready || ad == null || _showingFullScreen) return;
    if (!policy.canShowInterstitial(adsRemoved: storage.adsRemoved)) return;
    _interstitial = null;
    ad.fullScreenContentCallback = _fullScreenCallback(_loadInterstitial);
    policy.onInterstitialShown();
    ad.show();
  }

  // ---------------- Rewarded ----------------
  void _loadRewarded() {
    RewardedAd.load(
      adUnitId: AdIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (_) {
          _rewarded = null;
          Future.delayed(const Duration(seconds: 30), () {
            if (_rewarded == null) _loadRewarded();
          });
        },
      ),
    );
  }

  bool get rewardedAvailable => _ready && _rewarded != null && !policy.inGrace;

  /// Shows a rewarded ad (always player-initiated). Completes with true
  /// only if the reward was earned.
  Future<bool> showRewarded() {
    final ad = _rewarded;
    if (!rewardedAvailable || ad == null || _showingFullScreen) {
      return Future.value(false);
    }
    _rewarded = null;
    final result = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = _fullScreenCallback(() {
      _loadRewarded();
      if (!result.isCompleted) result.complete(earned);
    });
    ad.show(onUserEarnedReward: (_, _) => earned = true);
    return result.future;
  }

  // ---------------- App Open ----------------
  void _loadAppOpen() {
    if (storage.adsRemoved) return;
    AppOpenAd.load(
      adUnitId: AdIds.appOpen,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) => _appOpen = ad,
        onAdFailedToLoad: (_) => _appOpen = null,
      ),
    );
  }

  void _showAppOpen() {
    if (_skipNextAppOpen) {
      _skipNextAppOpen = false;
      return;
    }
    final ad = _appOpen;
    if (ad == null || _showingFullScreen) return;
    if (!policy.canShowAppOpen(adsRemoved: storage.adsRemoved)) return;
    _appOpen = null;
    ad.fullScreenContentCallback = _fullScreenCallback(_loadAppOpen);
    policy.markFullScreen();
    ad.show();
  }

  FullScreenContentCallback<T> _fullScreenCallback<T extends Ad>(
    VoidCallback onDone,
  ) {
    return FullScreenContentCallback<T>(
      onAdShowedFullScreenContent: (_) {
        _showingFullScreen = true;
        policy.markFullScreen();
      },
      onAdDismissedFullScreenContent: (ad) {
        _showingFullScreen = false;
        policy.markFullScreen();
        ad.dispose();
        onDone();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        _showingFullScreen = false;
        ad.dispose();
        onDone();
      },
    );
  }
}
