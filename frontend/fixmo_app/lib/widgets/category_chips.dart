import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/app_config.dart';

/// Horizontal pill-shaped category chips for filtering incidents.
/// Unselected: dark gray (#2A2A2A), selected: primary green (#00D9A3).
class CategoryChips extends StatelessWidget {
  const CategoryChips({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String?> onCategorySelected;

  /// Default categories per plan: Incidents, Roads, Water, Waste, Lighting, Environment.
  static const List<String> defaultCategories = [
    'Incidents',
    'Roads',
    'Water',
    'Waste',
    'Lighting',
    'Environment',
  ];

  static const Color _unselectedBg = Color(0xFF2A2A2A);
  static const Color _textColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = selectedCategory == category;
          return Material(
            color: isSelected ? Color(AppConfig.primaryColorValue) : _unselectedBg,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: () => onCategorySelected(isSelected ? null : category),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Center(
                  child: Text(
                    category,
                    style: const TextStyle(
                      color: _textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
