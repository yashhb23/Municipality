import 'package:flutter/material.dart';

/// Horizontal pill-shaped category chips for filtering incidents.
/// All colors sourced from Theme.of(context).
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

  static const List<String> defaultCategories = [
    'Incidents',
    'Roads',
    'Water',
    'Waste',
    'Lighting',
    'Environment',
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
            color: isSelected ? cs.primary : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: () => onCategorySelected(isSelected ? null : category),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Center(
                  child: Text(
                    category,
                    style: TextStyle(
                      color: isSelected ? cs.onPrimary : cs.onSurface,
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
