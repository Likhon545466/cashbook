import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/settings_provider.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Appearance',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const _Title('Theme Mode'),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: _ModeOption(
                      label: 'System',
                      icon: Icons.phone_android_rounded,
                      selected: settings.themeMode == ThemeMode.system,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        settings.setThemeMode(ThemeMode.system);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ModeOption(
                      label: 'Light',
                      icon: Icons.light_mode_outlined,
                      selected: settings.themeMode == ThemeMode.light,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        settings.setThemeMode(ThemeMode.light);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ModeOption(
                      label: 'Dark',
                      icon: Icons.dark_mode_outlined,
                      selected: settings.themeMode == ThemeMode.dark,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        settings.setThemeMode(ThemeMode.dark);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          const _Title('Dynamic Color'),
          const SizedBox(height: 10),
          Card(
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              secondary: const Icon(Icons.wallpaper_rounded),
              title: const Text(
                'Use wallpaper colors',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                settings.dynamicColorEnabled
                    ? 'On. Supported Android devices use system colors.'
                    : 'Off. CashBook uses your selected Theme Color.',
              ),
              value: settings.dynamicColorEnabled,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                settings.setDynamicColorEnabled(value);
              },
            ),
          ),
          const SizedBox(height: 22),
          const _Title('Theme Color'),
          const SizedBox(height: 6),
          Text(
            settings.dynamicColorEnabled
                ? 'Fallback color if wallpaper colors are unavailable.'
                : 'Primary color used across CashBook.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          AnimatedOpacity(
            opacity: settings.dynamicColorEnabled ? 0.60 : 1,
            duration: const Duration(milliseconds: 180),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: MaterialPalette.values.map((item) {
                return _ColorChoice(
                  label: item.label,
                  color: item.seed,
                  selected: settings.materialPalette == item,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    settings.setMaterialPalette(item);
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected ? scheme.primary : scheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.12)
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? scheme.primary.withValues(alpha: 0.55)
                : Theme.of(context).dividerColor,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final String text;
  const _Title(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleSmall);
  }
}

class _ColorChoice extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorChoice({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.14)
              : Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.70)
                : Theme.of(context).dividerColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : foreground,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
