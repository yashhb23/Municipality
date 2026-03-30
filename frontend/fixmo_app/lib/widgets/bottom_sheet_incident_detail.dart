import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/report_model.dart';
import 'category_chips.dart';

/// Draggable bottom sheet showing selected incident summary and category filter chips.
/// All colors sourced from Theme.of(context).
class BottomSheetIncidentDetail extends StatelessWidget {
  const BottomSheetIncidentDetail({
    super.key,
    required this.scrollController,
    this.report,
    required this.onViewDetails,
    this.selectedCategory,
    this.onCategoryChanged,
    this.categories,
  });

  final ScrollController scrollController;
  final ReportModel? report;
  final ValueChanged<ReportModel> onViewDetails;
  final String? selectedCategory;
  final ValueChanged<String?>? onCategoryChanged;
  final List<String>? categories;

  static const double _topRadius = 24;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final chipCategories = categories ?? CategoryChips.defaultCategories;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(_topRadius)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface.withOpacity(0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(_topRadius)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              _buildDragHandle(cs),
              const SizedBox(height: 12),
              if (onCategoryChanged != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: CategoryChips(
                    categories: chipCategories,
                    selectedCategory: selectedCategory,
                    onCategorySelected: onCategoryChanged!,
                  ),
                ),
              if (report != null) ...[
                Text(
                  report!.title,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.onSurface),
                ),
                const SizedBox(height: 8),
                Text(
                  '${report!.address} • ${report!.timeAgo}',
                  style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.5)),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => onViewDetails(report!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('View Details'),
                  ),
                ),
              ] else ...[
                Text(
                  'Select an incident on the map',
                  style: TextStyle(fontSize: 16, color: cs.onSurface.withOpacity(0.5)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDragHandle(ColorScheme cs) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: cs.onSurface.withOpacity(0.2),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
