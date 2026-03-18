import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../models/report_model.dart';
import '../services/supabase_service.dart';
import '../services/reports_service.dart';
import '../widgets/report_detail_card.dart';

/// Dark card-based list of reports with thumbnails and status badges.
/// Pull-to-refresh. Uses SupabaseService.getAllReports() with ReportsService fallback.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<ReportModel> _reports = [];
  bool _loading = true;
  String? _error;

  static const Color _bg = Color(0xFF0A0A0A);
  static const Color _surface = Color(0xFF1A1A1A);
  static const Color _primary = Color(0xFF00D9A3);

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final supabase = context.read<SupabaseService>();
      List<ReportModel> list = await supabase.getAllReports();
      if (list.isEmpty) {
        final reportsService = context.read<ReportsService>();
        list = reportsService.allReports;
      }
      if (mounted) {
        setState(() {
          _reports = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final reportsService = context.read<ReportsService>();
        setState(() {
          _reports = reportsService.allReports;
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _showReportDetail(ReportModel report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: ReportDetailCard(
              report: report,
              onClose: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        title: const Text(
          'History',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _loadReports,
        color: _primary,
        backgroundColor: _surface,
        child: _loading && _reports.isEmpty
            ? const Center(
                child: CircularProgressIndicator(color: _primary),
              )
            : _reports.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade600),
                        const SizedBox(height: 16),
                        Text(
                          'No reports yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pull to refresh',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: _reports.length,
                    itemBuilder: (context, index) {
                      final report = _reports[index];
                      return _HistoryCard(
                        report: report,
                        onTap: () => _showReportDetail(report),
                      );
                    },
                  ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.report, required this.onTap});

  final ReportModel report;
  final VoidCallback onTap;

  static const Color _cardBg = Color(0xFF1A1A1A);
  static const Color _primary = Color(0xFF00D9A3);

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.amber;
      case 'in_progress':
        return Colors.blue;
      case 'resolved':
        return const Color(0xFF10B981);
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = report.imageUrls.isNotEmpty ? report.imageUrls.first : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: _cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: thumbnailUrl != null
                      ? Image.network(
                          thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report.category,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor(report.status).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _statusColor(report.status).withOpacity(0.6),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _statusLabel(report.status),
                            style: TextStyle(
                              color: _statusColor(report.status),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          report.timeAgo,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade500),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF2A2A2A),
      child: Icon(Icons.image_not_supported_outlined, color: Colors.grey.shade600),
    );
  }
}
