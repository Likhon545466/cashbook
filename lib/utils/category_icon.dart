import 'package:flutter/material.dart';

class CategoryIcon {
  CategoryIcon._();

  static IconData forName(String category, {required bool isIncome}) {
    final name = category.toLowerCase();

    if (isIncome) {
      if (name.contains('salary')) return Icons.badge_outlined;
      if (name.contains('freelance')) return Icons.laptop_mac_outlined;
      if (name.contains('business')) return Icons.storefront_outlined;
      return Icons.savings_outlined;
    }

    if (name.contains('food')) return Icons.restaurant_outlined;
    if (name.contains('transport')) return Icons.directions_car_outlined;
    if (name.contains('shopping')) return Icons.shopping_bag_outlined;
    if (name.contains('bill')) return Icons.receipt_long_outlined;
    if (name.contains('rent')) return Icons.home_outlined;
    if (name.contains('health')) return Icons.health_and_safety_outlined;
    if (name.contains('entertainment')) return Icons.movie_outlined;

    return Icons.category_outlined;
  }
}
