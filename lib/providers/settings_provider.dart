import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../services/database_service.dart';
import '../utils/money_formatter.dart';

enum UpdateFrequency {
  onStartup('Every Startup', 'Check for updates every time CashBook opens'),
  daily('Once Daily', 'Check at most once every 24 hours'),
  weekly('Once a Week', 'Check at most once every 7 days'),
  manualOnly('Manual Only', 'Never check automatically in the background');

  final String title;
  final String description;
  const UpdateFrequency(this.title, this.description);
}

class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._databaseService);

  final DatabaseService _databaseService;

  static const _themeKey = 'theme_mode';
  static const _hideBalanceKey = 'hide_balance';
  static const _dynamicColorKey = 'dynamic_color_enabled';
  static const _materialColorKey = 'material_color';
  static const _currencySymbolKey = 'currency_symbol';
  static const _currencyCodeKey = 'currency_code';
  static const _dailyReminderEnabledKey = 'daily_reminder_enabled';
  static const _dailyReminderTimeKey = 'daily_reminder_time';
  static const _updateFrequencyKey = 'update_check_frequency';
  static const _lastUpdateCheckKey = 'last_update_check_time';

  ThemeMode _themeMode = ThemeMode.system;
  MaterialPalette _materialPalette = MaterialPalette.emerald;
  bool _dynamicColorEnabled = true;
  bool _hideBalance = false;
  String _currencySymbol = '৳';
  String _currencyCode = 'BDT';
  bool _dailyReminderEnabled = false;
  TimeOfDay _dailyReminderTime = const TimeOfDay(hour: 21, minute: 0);
  UpdateFrequency _updateFrequency = UpdateFrequency.onStartup;
  DateTime? _lastUpdateCheckTime;
  bool _isLoaded = false;

  ThemeMode get themeMode => _themeMode;
  MaterialPalette get materialPalette => _materialPalette;
  Color get materialSeed => _materialPalette.seed;
  bool get dynamicColorEnabled => _dynamicColorEnabled;
  bool get hideBalance => _hideBalance;
  String get currencySymbol => _currencySymbol;
  String get currencyCode => _currencyCode;
  bool get dailyReminderEnabled => _dailyReminderEnabled;
  TimeOfDay get dailyReminderTime => _dailyReminderTime;
  UpdateFrequency get updateFrequency => _updateFrequency;
  DateTime? get lastUpdateCheckTime => _lastUpdateCheckTime;
  bool get isLoaded => _isLoaded;

  /// Evaluates whether an automated update check should be performed based on user frequency setting.
  bool shouldCheckForUpdate() {
    if (_updateFrequency == UpdateFrequency.manualOnly) return false;
    if (_updateFrequency == UpdateFrequency.onStartup) return true;
    if (_lastUpdateCheckTime == null) return true;

    final now = DateTime.now();
    final diff = now.difference(_lastUpdateCheckTime!);

    if (_updateFrequency == UpdateFrequency.daily) {
      return diff.inHours >= 24;
    }
    if (_updateFrequency == UpdateFrequency.weekly) {
      return diff.inDays >= 7;
    }

    return true;
  }

  Future<void> loadTheme() async {
    try {
      final savedTheme = await _databaseService.getSetting(_themeKey);
      final savedHide = await _databaseService.getSetting(_hideBalanceKey);
      final savedDynamic = await _databaseService.getSetting(_dynamicColorKey);
      final savedMaterial = await _databaseService.getSetting(
        _materialColorKey,
      );
      final legacyMaterial = await _databaseService.getSetting('theme_accent');
      final savedCurrencySymbol = await _databaseService.getSetting(_currencySymbolKey);
      final savedCurrencyCode = await _databaseService.getSetting(_currencyCodeKey);
      final savedReminderEnabled = await _databaseService.getSetting(_dailyReminderEnabledKey);
      final savedReminderTime = await _databaseService.getSetting(_dailyReminderTimeKey);
      final savedUpdateFreq = await _databaseService.getSetting(_updateFrequencyKey);
      final savedLastCheck = await _databaseService.getSetting(_lastUpdateCheckKey);

      _themeMode = switch (savedTheme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

      _hideBalance = savedHide == 'true';
      _dynamicColorEnabled = savedDynamic != 'false';
      _materialPalette = AppColors.materialFromStorage(
        savedMaterial ?? legacyMaterial,
      );
      if (savedCurrencySymbol != null && savedCurrencySymbol.isNotEmpty) {
        _currencySymbol = savedCurrencySymbol;
      }
      if (savedCurrencyCode != null && savedCurrencyCode.isNotEmpty) {
        _currencyCode = savedCurrencyCode;
      }
      MoneyFormatter.currencySymbol = _currencySymbol;

      _dailyReminderEnabled = savedReminderEnabled == 'true';
      if (savedReminderTime != null && savedReminderTime.contains(':')) {
        final parts = savedReminderTime.split(':');
        if (parts.length == 2) {
          final h = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          if (h != null && m != null) {
            _dailyReminderTime = TimeOfDay(hour: h, minute: m);
          }
        }
      }

      if (savedUpdateFreq != null) {
        for (final freq in UpdateFrequency.values) {
          if (freq.name == savedUpdateFreq) {
            _updateFrequency = freq;
            break;
          }
        }
      }

      if (savedLastCheck != null) {
        _lastUpdateCheckTime = DateTime.tryParse(savedLastCheck);
      }
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };

    await _databaseService.setSetting(_themeKey, value);
  }

  Future<void> setDynamicColorEnabled(bool value) async {
    if (_dynamicColorEnabled == value) return;
    _dynamicColorEnabled = value;
    notifyListeners();
    await _databaseService.setSetting(_dynamicColorKey, value.toString());
  }

  Future<void> setMaterialPalette(MaterialPalette value) async {
    if (_materialPalette == value) return;
    _materialPalette = value;
    notifyListeners();
    await _databaseService.setSetting(_materialColorKey, value.name);
  }

  Future<void> setHideBalance(bool value) async {
    if (_hideBalance == value) return;
    _hideBalance = value;
    notifyListeners();
    await _databaseService.setSetting(_hideBalanceKey, value.toString());
  }

  Future<void> setCurrency({required String symbol, required String code}) async {
    if (_currencySymbol == symbol && _currencyCode == code) return;
    _currencySymbol = symbol;
    _currencyCode = code;
    MoneyFormatter.currencySymbol = symbol;
    notifyListeners();
    await _databaseService.setSetting(_currencySymbolKey, symbol);
    await _databaseService.setSetting(_currencyCodeKey, code);
  }

  Future<void> setDailyReminderEnabled(bool value) async {
    if (_dailyReminderEnabled == value) return;
    _dailyReminderEnabled = value;
    notifyListeners();
    await _databaseService.setSetting(_dailyReminderEnabledKey, value.toString());
  }

  Future<void> setDailyReminderTime(TimeOfDay time) async {
    _dailyReminderTime = time;
    notifyListeners();
    await _databaseService.setSetting(
      _dailyReminderTimeKey,
      '${time.hour}:${time.minute}',
    );
  }

  Future<void> setUpdateFrequency(UpdateFrequency value) async {
    if (_updateFrequency == value) return;
    _updateFrequency = value;
    notifyListeners();
    await _databaseService.setSetting(_updateFrequencyKey, value.name);
  }

  Future<void> recordUpdateCheckNow() async {
    _lastUpdateCheckTime = DateTime.now();
    notifyListeners();
    await _databaseService.setSetting(
      _lastUpdateCheckKey,
      _lastUpdateCheckTime!.toIso8601String(),
    );
  }

  Future<void> toggleBalanceVisibility() async {
    await setHideBalance(!_hideBalance);
  }
}

