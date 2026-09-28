# Merge 2048 — EliteP

A modern take on 2048 built with Flutter. Package: `com.elitep.merge2048`.

## Features
- Classic **4×4** board. **5×5** unlocks at player level 3 and **6×6** at level 6. You earn XP from the score of each finished round.
- Four-way swipes with slide, merge-pop and spawn animations. Arrow keys also work on emulators.
- **Undo**: 3 free per game. After that, a rewarded ad gives +2.
- **Continue** after losing: a rewarded ad removes the 4 smallest tiles (once per game).
- **Hints**: the best move is shown as an arrow. Each hint costs 30 coins or a rewarded ad.
- **Daily Challenge**: every player gets the same seed. The day is computed in UTC, so the starting board *and* every spawn come out the same for identical moves. Undo and Continue are disabled. The first finish of the day gives +50 coins.
- Best score saved for each board, plus the best daily score for each day.
- Coins from each round (score/100 plus a bonus for big tiles). A rewarded ad can double them.
- 6 tile colour themes (2 free, 4 bought with coins). The whole app follows the selected theme.
- The UI is in English with a full Arabic (RTL) translation. The language can follow the system or be picked in Settings.
- Sound effects with a mute toggle, light haptics with their own toggle.
- EliteP splash, Home, board select, Themes, Settings and a Privacy Policy link.
- The game in progress is auto-saved and resumes from the board select screen.
- Portrait only. The board sizes itself to any screen.

## Run
```bash
flutter pub get
flutter run
flutter analyze   # must be clean
flutter test      # game logic, ad rules, controller and widget smoke tests
```

## Project layout
```
lib/
  main.dart           providers, theme, localisation
  game/               board.dart (pure rules), seeded_random.dart, hint.dart (AI),
                      game_controller.dart (undo/continue/hint/save/rewards)
  screens/            splash, home, mode_select ("levels"), game, themes, settings
  services/           ad_service, ad_policy, iap_service, storage_service, audio_service
  widgets/            board_view (animated tiles), common (banner slot, buttons…)
  data/               game_modes (modes, daily seed, levels), tile_themes, strings (EN/AR)
assets/sounds/        move, merge, win, gameover, coin (generated WAVs)
store/icon_512.png    Play Store icon
```

## AdMob: where to change the IDs
The app ships with **Google test IDs**. Before release:
1. `lib/services/ad_service.dart` → class `AdIds`: paste the EliteP unit IDs into
   `_elitepBanner`, `_elitepInterstitial`, `_elitepRewarded` and `_elitepAppOpen`,
   then set `useTestAds = false`.
2. `android/app/src/main/AndroidManifest.xml` → meta-data
   `com.google.android.gms.ads.APPLICATION_ID`: replace it with the EliteP AdMob **App ID**.
3. AdMob → *Privacy & messaging*: create the GDPR (UMP) consent message. The app
   already asks for consent before it initialises the SDK. When the user is in scope,
   Settings shows an "Ad privacy choices" entry.

### Ad rules (all in `AdService` / `AdPolicy`)
| Format | Where / when |
|---|---|
| Banner | Bottom of Home and board-select screens only. Never during gameplay. |
| Interstitial | After every 3 finished rounds, at a natural break (New Game / leaving the game-over screen). |
| Rewarded | Only when the player asks: hint, extra undos, continue, double coins. |
| App Open | When the app returns from the background. |
| Global | ≥ 120 s between any two full-screen ads. No ads at all in the first 60 s after the first launch. |
| Remove Ads IAP | Turns off Banner, Interstitial and App Open. Rewarded ads stay available. |

## In-app purchase
In Play Console, create a one-time (non-consumable) product with id **`remove_ads`**
(defined in `lib/services/iap_service.dart`). Settings has *Remove Ads* and *Restore purchases*.

## Privacy policy
Set the URL in `lib/widgets/common.dart` → `privacyPolicyUrl`.

## Build the AAB for Google Play
1. Create an upload keystore (once):
   ```bash
   keytool -genkey -v -keystore ~/elitep-upload.jks -keyalg RSA -keysize 2048 \
     -validity 10000 -alias upload
   ```
2. Create `android/key.properties` (it is git-ignored, so never commit it):
   ```
   storePassword=...
   keyPassword=...
   keyAlias=upload
   storeFile=/absolute/path/to/elitep-upload.jks
   ```
   `android/app/build.gradle.kts` already picks it up automatically. Without the file,
   release builds are signed with the debug key.
3. Bump `version:` in `pubspec.yaml` (e.g. `1.0.1+2`; the number after `+` is the versionCode).
4. Build:
   ```bash
   flutter build appbundle --release
   ```
5. Upload `build/app/outputs/bundle/release/app-release.aab` to Play Console.
   In the Data safety / Ads sections, declare that the app contains ads (AdMob) and in-app purchases.
