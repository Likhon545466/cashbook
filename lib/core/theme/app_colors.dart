import 'package:flutter/material.dart';

enum MaterialPalette { emerald, blue, purple, amber, rose }

extension MaterialPaletteX on MaterialPalette {
  String get label {
    switch (this) {
      case MaterialPalette.emerald:
        return 'Emerald';
      case MaterialPalette.blue:
        return 'Blue';
      case MaterialPalette.purple:
        return 'Purple';
      case MaterialPalette.amber:
        return 'Amber';
      case MaterialPalette.rose:
        return 'Rose';
    }
  }

  Color get seed {
    switch (this) {
      case MaterialPalette.emerald:
        return const Color(0xFF0F6B4F);
      case MaterialPalette.blue:
        return const Color(0xFF315CBE);
      case MaterialPalette.purple:
        return const Color(0xFF7354B4);
      case MaterialPalette.amber:
        return const Color(0xFF9A6410);
      case MaterialPalette.rose:
        return const Color(0xFFA94767);
    }
  }
}

class AppColors {
  AppColors._();

  static const lightBackground = Color(0xFFF4F6F5);
  static const lightCard = Color(0xFFFFFFFF);
  static const darkBackground = Color(0xFF0B0F0E);
  static const darkCard = Color(0xFF121615);

  static MaterialPalette materialFromStorage(String? value) {
    for (final item in MaterialPalette.values) {
      if (item.name == value) return item;
    }
    return MaterialPalette.emerald;
  }
}

class AppSemanticColors {
  AppSemanticColors._();

  static Color income(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF50C99D)
        : const Color(0xFF11875D);
  }

  static Color expense(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFFF8484)
        : const Color(0xFFD34A4A);
  }

  static Color savings(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF67B8FF)
        : const Color(0xFF287BB8);
  }

  static Color warning(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFFFC75A)
        : const Color(0xFFB77916);
  }
}
