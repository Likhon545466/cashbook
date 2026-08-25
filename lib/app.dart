import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'navigation/main_navigation.dart';
import 'providers/settings_provider.dart';
import 'widgets/app_lock_gate.dart';

class CashBookApp extends StatelessWidget {
  const CashBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final useDynamic = settings.dynamicColorEnabled;

        return MaterialApp(
          title: 'CashBook',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(
            seed: settings.materialSeed,
            dynamicScheme: useDynamic ? lightDynamic : null,
          ),
          darkTheme: AppTheme.darkTheme(
            seed: settings.materialSeed,
            dynamicScheme: useDynamic ? darkDynamic : null,
          ),
          themeMode: settings.themeMode,
          themeAnimationDuration: const Duration(milliseconds: 260),
          themeAnimationCurve: Curves.easeOutCubic,
          home: const AppLockGate(child: MainNavigation()),
        );
      },
    );
  }
}
