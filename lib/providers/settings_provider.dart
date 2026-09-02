import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../services/database_service.dart';
import '../utils/money_formatter.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._databaseService);

  final DatabaseService _databaseService;

  static const _themeKey = 'theme_mode';
  static const _hideBalanceKey = 'hide_balance';
  static const _dynamicColorKey = 'dynamic_color_enabled';
  static const _materialColorKey = 'material_color';
  static const _currencySymbolKey = 'currency_symbol';
  static const _currencyCodeKey = 'currency_code';

  ThemeMode _themeMode = ThemeMode.system;
  MaterialPalette _materialPalette = MaterialPalette.emerald;
  bool _dynamicColorEnabled = true;
  bool _hideBalance = false;
  String _currencySymbol = '৳';
  String _currencyCode = 'BDT';
  bool _isLoaded = false;

  ThemeMode get themeMode => _themeMode;
  MaterialPalette get materialPalette => _materialPalette;
  Color get materialSeed => _materialPalette.seed;
  bool get dynamicColorEnabled => _dynamicColorEnabled;
  bool get hideBalance => _hideBalance;
  String get currencySymbol => _currencySymbol;
  String get currencyCode => _currencyCode;
  bool get isLoaded => _isLoaded;

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

  Future<void> toggleBalanceVisibility() async {
    await setHideBalance(!_hideBalance);
  }
}

