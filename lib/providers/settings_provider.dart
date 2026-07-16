import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/currencies.dart';

/// Holds app-wide settings (currency, theme) and persists them locally via
/// SharedPreferences.
class SettingsProvider extends ChangeNotifier {
  static const _currencyCodeKey = 'settings.currencyCode';
  static const _themeModeKey = 'settings.themeMode';
  static const _hasSeenOnboardingKey = 'settings.hasSeenOnboarding';

  String _currencyCode = 'USD';

  String get currencyCode => _currencyCode;
  Currency get currency => Currencies.byCode(_currencyCode);
  String get currencySymbol => currency.symbol;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  bool _hasSeenOnboarding = false;
  bool get hasSeenOnboarding => _hasSeenOnboarding;

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _currencyCode = prefs.getString(_currencyCodeKey) ?? 'USD';
    _themeMode = _themeModeFromString(prefs.getString(_themeModeKey));
    _hasSeenOnboarding = prefs.getBool(_hasSeenOnboardingKey) ?? false;
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setHasSeenOnboarding() async {
    _hasSeenOnboarding = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenOnboardingKey, true);
  }

  Future<void> setCurrencyCode(String code) async {
    _currencyCode = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyCodeKey, code);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
  }

  static ThemeMode _themeModeFromString(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  Map<String, dynamic> exportAll() => {
        'currencyCode': _currencyCode,
        'themeMode': _themeMode.name,
      };

  Future<void> importAll(Map<String, dynamic> data) async {
    final code = data['currencyCode'] as String?;
    if (code != null) await setCurrencyCode(code);
    final mode = data['themeMode'] as String?;
    if (mode != null) await setThemeMode(_themeModeFromString(mode));
  }
}
