import 'package:flutter/material.dart';

/// Modal bottom sheet for advanced report filtering on the map.
///
/// Provides multi-select chips for status and priority, single-select
/// for date range, and a distance slider (only when GPS is available).
class AdvancedFilterModal extends StatefulWidget {
  final Set<String> statusFilters;
  final String dateRange;
  final Set<String> priorityFilters;
  final double? distanceKm;
  final bool hasUserLocation;
  final void Function(Set<String> status, String date, Set<String> priority, double? distance) onApply;
  final VoidCallback onReset;

  const AdvancedFilterModal({
    super.key,
    required this.statusFilters,
    required this.dateRange,
    required this.priorityFilters,
    required this.distanceKm,
    required this.hasUserLocation,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<AdvancedFilterModal> createState() => _AdvancedFilterModalState();
}

class _AdvancedFilterModalState extends State<AdvancedFilterModal> {
  late Set<String> _status;
  late String _date;
  late Set<String> _priority;
  late double? _distance;

  static const _statuses = [
    ('pending', 'Pending'),
    ('in_progress', 'In Progress'),
    ('resolved', 'Resolved'),
    ('rejected', 'Rejected'),
  ];

  static const _dates = [
    ('24h', 'Last 24h'),
    ('7d', 'Last 7 days'),
    ('30d', 'Last 30 days'),
    ('all', 'All time'),
  ];

  static const _priorities = [
    ('1', 'Low'),
    ('2', 'Medium'),
    ('3', 'High'),
    ('4', 'Critical'),
  ];

  @override
  void initState() {
    super.initState();
    _status = Set.of(widget.statusFilters);
    _date = widget.dateRange;
    _priority = Set.of(widget.priorityFilters);
    _distance = widget.distanceKm;
  }

  bool get _hasAnyFilter =>
      _status.isNotEmpty || _priority.isNotEmpty || _date != 'all' || _distance != null;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Advanced Filters', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              if (_hasAnyFilter)
                TextButton(
                  onPressed: () {
                    widget.onReset();
                    Navigator.pop(context);
                  },
                  child: Text('Reset', style: TextStyle(color: cs.error)),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Status section
          _sectionLabel(tt, 'Status'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _statuses.map((s) => _multiChip(s.$1, s.$2, _status, cs)).toList(),
          ),
          const SizedBox(height: 20),

          // Date range section
          _sectionLabel(tt, 'Date Range'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _dates.map((d) => _singleChip(d.$1, d.$2, _date, (v) => setState(() => _date = v), cs)).toList(),
          ),
          const SizedBox(height: 20),

          // Priority section
          _sectionLabel(tt, 'Priority'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _priorities.map((p) => _multiChip(p.$1, p.$2, _priority, cs)).toList(),
          ),

          // Distance slider (only if GPS available)
          if (widget.hasUserLocation) ...[
            const SizedBox(height: 20),
            _sectionLabel(tt, 'Distance from you'),
            const SizedBox(height: 4),
            Row(
              children: [
                Checkbox(
                  value: _distance != null,
                  onChanged: (v) => setState(() => _distance = v == true ? 10 : null),
                  activeColor: cs.primary,
                ),
                Expanded(
                  child: Slider(
                    value: _distance ?? 10,
                    min: 1,
                    max: 50,
                    divisions: 49,
                    label: '${(_distance ?? 10).round()} km',
                    activeColor: cs.primary,
                    onChanged: _distance != null ? (v) => setState(() => _distance = v) : null,
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    _distance != null ? '${_distance!.round()} km' : 'Off',
                    style: tt.bodySmall,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),

          // Apply button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onApply(_status, _date, _priority, _distance);
                Navigator.pop(context);
              },
              child: const Text('Apply Filters'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(TextTheme tt, String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text, style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
    );
  }

  /// Multi-select chip — toggles membership in the given [set].
  Widget _multiChip(String value, String label, Set<String> set, ColorScheme cs) {
    final selected = set.contains(value);
    return FilterChip(
      label: Text(label),
      selected: selected,
      selectedColor: cs.primary.withOpacity(0.2),
      checkmarkColor: cs.primary,
      onSelected: (on) => setState(() => on ? set.add(value) : set.remove(value)),
    );
  }

  /// Single-select chip — sets the current value.
  Widget _singleChip(String value, String label, String current, ValueChanged<String> onSelect, ColorScheme cs) {
    final selected = current == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: cs.primary.withOpacity(0.2),
      onSelected: (_) => onSelect(value),
    );
  }
}
