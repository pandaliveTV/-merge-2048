import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/game_modes.dart';

/// Persists progress (level/XP, coins, best scores, settings, saved games).
class StorageService extends ChangeNotifier {
  late SharedPreferences _p;

  int coins = 0;
  int xp = 0;
  bool muted = false;
  bool vibration = true;
  bool adsRemoved = false;

  /// 'system', 'en' or 'ar'.
  String language = 'system';
  String tileTheme = 'classic';
  Set<String> ownedThemes = {'classic', 'midnight'};

  /// Milliseconds since epoch of the very first launch.
  int firstLaunch = 0;

  int get level => PlayerLevel.levelFor(xp);

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    coins = _p.getInt('coins') ?? 0;
    xp = _p.getInt('xp') ?? 0;
    muted = _p.getBool('muted') ?? false;
    vibration = _p.getBool('vibration') ?? true;
    adsRemoved = _p.getBool('adsRemoved') ?? false;
    language = _p.getString('language') ?? 'system';
    tileTheme = _p.getString('tileTheme') ?? 'classic';
    ownedThemes = {'classic', 'midnight', ...?_p.getStringList('ownedThemes')};
    firstLaunch = _p.getInt('firstLaunch') ?? 0;
    if (firstLaunch == 0) {
      firstLaunch = DateTime.now().millisecondsSinceEpoch;
      await _p.setInt('firstLaunch', firstLaunch);
    }
  }

  // ---------------- Coins & XP ----------------
  void addCoins(int n) {
    coins += n;
    _p.setInt('coins', coins);
    notifyListeners();
  }

  bool spend(int n) {
    if (coins < n) return false;
    addCoins(-n);
    return true;
  }

  /// Adds XP and returns the new level if the player levelled up.
  int? addXp(int n) {
    final before = level;
    xp += n;
    _p.setInt('xp', xp);
    notifyListeners();
    return level > before ? level : null;
  }

  bool isUnlocked(GameMode m) => m.daily || level >= m.unlockLevel;

  // ---------------- Scores ----------------
  int best(String modeId) => _p.getInt('best_$modeId') ?? 0;

  void submitBest(String modeId, int score) {
    if (score <= best(modeId)) return;
    _p.setInt('best_$modeId', score);
    notifyListeners();
  }

  int dailyBest(String day) => _p.getInt('dailyBest_$day') ?? 0;

  void submitDaily(String day, int score) {
    if (score > dailyBest(day)) _p.setInt('dailyBest_$day', score);
    notifyListeners();
  }

  /// True only the first time it is called for [day].
  bool claimDailyBonus(String day) {
    final key = 'dailyBonus_$day';
    if (_p.getBool(key) ?? false) return false;
    _p.setBool(key, true);
    return true;
  }

  // ---------------- Saved games ----------------
  Map<String, dynamic>? loadGame(String modeId) {
    final raw = _p.getString('save_$modeId');
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  bool hasSavedGame(String modeId) => _p.containsKey('save_$modeId');

  void saveGame(String modeId, Map<String, dynamic> data) =>
      _p.setString('save_$modeId', jsonEncode(data));

  void clearGame(String modeId) {
    _p.remove('save_$modeId');
    notifyListeners();
  }

  // ---------------- Settings ----------------
  void setMuted(bool v) {
    muted = v;
    _p.setBool('muted', v);
    notifyListeners();
  }

  void setVibration(bool v) {
    vibration = v;
    _p.setBool('vibration', v);
    notifyListeners();
  }

  void setLanguage(String v) {
    language = v;
    _p.setString('language', v);
    notifyListeners();
  }

  void setAdsRemoved(bool v) {
    adsRemoved = v;
    _p.setBool('adsRemoved', v);
    notifyListeners();
  }

  // ---------------- Themes ----------------
  void unlockTheme(String id) {
    ownedThemes.add(id);
    _p.setStringList('ownedThemes', ownedThemes.toList());
    selectTheme(id);
  }

  void selectTheme(String id) {
    tileTheme = id;
    _p.setString('tileTheme', id);
    notifyListeners();
  }
}
