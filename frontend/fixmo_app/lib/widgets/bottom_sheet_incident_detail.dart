import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/report_model.dart';
import 'category_chips.dart';

/// Draggable dark bottom sheet showing selected incident summary and category filter chips.
/// Initial 25%, max 60%, blur background, 24dp top radius, green "View Details" CTA.
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

  static const Color _sheetBg = Color(0xE6000000);
  static const Color _primary = Color(0xFF00D9A3);
  static const double _topRadius = 24;

  @override
  Widget build(BuildContext context) {
    final chipCategories = categories ?? CategoryChips.defaultCategories;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(_topRadius)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: _sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(_topRadius)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              _buildDragHandle(),
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
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${report!.address} • ${report!.timeAgo}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => onViewDetails(report!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('View Details'),
                  ),
                ),
              ] else ...[
                Text(
                  'Select an incident on the map',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
