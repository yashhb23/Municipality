import 'package:flutter/material.dart';
import '../models/report_model.dart';

/// Report detail card displayed when a map pin is tapped.
/// All colors sourced from Theme.of(context).
class ReportDetailCard extends StatelessWidget {
  final ReportModel report;
  final VoidCallback onClose;

  const ReportDetailCard({
    super.key,
    required this.report,
    required this.onClose,
  });

  static const Color _surface = Color(0xFF1A1A1A);
  static const Color _primary = Color(0xFF00D9A3);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.onSurface.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildImageSection(context, cs),
          _buildDetails(context, cs),
        ],
      ),
    );
  }

  Widget _buildImageSection(BuildContext context, ColorScheme cs) {
    return Stack(
      children: [
        if (report.imageUrls.isNotEmpty)
          ClipRRect(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            child: Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(color: cs.surfaceContainerHighest),
              child: Image.network(
                report.imageUrls.first,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: cs.surfaceContainerHighest,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary)),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: cs.surfaceContainerHighest,
                    child: Center(child: Icon(Icons.image_not_supported, color: cs.onSurface.withOpacity(0.3), size: 32)),
                  );
                },
              ),
            ),
          ),
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(20)),
            child: IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close, color: Colors.white, size: 20),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ),
        ),
        if (report.isCurrentUser)
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person, color: cs.onPrimary, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Your Report',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDetails(BuildContext context, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  report.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: report.statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: report.statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  report.status.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: report.statusColor, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(report.categoryIcon, size: 16, color: cs.primary),
              const SizedBox(width: 4),
              Text(
                report.category,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 12),
              ...List.generate(
                3,
                (index) => Icon(
                  Icons.priority_high,
                  size: 12,
                  color: index < report.priority ? Colors.red.shade400 : cs.onSurface.withOpacity(0.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            report.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurface.withOpacity(0.7)),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: cs.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
                child: Icon(Icons.person, size: 16, color: cs.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(report.reporterName, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
                    Text(report.timeAgo, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface.withOpacity(0.5))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on, size: 12, color: cs.onSurface.withOpacity(0.5)),
                    const SizedBox(width: 4),
                    Text(report.municipality, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurface.withOpacity(0.5))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cs.onSurface.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                Icon(Icons.place, size: 16, color: cs.onSurface.withOpacity(0.5)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(report.address, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface.withOpacity(0.7))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
