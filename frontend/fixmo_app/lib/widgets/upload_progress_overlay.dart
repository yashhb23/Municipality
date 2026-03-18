import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Dark-themed upload progress overlay. Progress arc drawn with CustomPainter
/// (no rotation) so center text stays upright. Green accent #00D9A3.
class UploadProgressOverlay extends StatefulWidget {
  final double progress; // 0.0 to 1.0
  final String stage; // "Optimizing...", "Uploading...", "Saving..."
  final bool showSuccess;

  const UploadProgressOverlay({
    super.key,
    required this.progress,
    required this.stage,
    this.showSuccess = false,
  });

  @override
  State<UploadProgressOverlay> createState() => _UploadProgressOverlayState();
}

class _UploadProgressOverlayState extends State<UploadProgressOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const Color _primary = Color(0xFF00D9A3);
  static const Color _trackColor = Color(0xFF2A2A2A);
  static const Color _overlayBg = Color(0xD9000000);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        color: _overlayBg,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: widget.showSuccess ? _buildSuccess() : _buildProgress(),
          ),
        ),
      ),
    );
  }

  Widget _buildProgress() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(160, 160),
                    painter: _ProgressRingPainter(
                      progress: widget.progress,
                      trackColor: _trackColor,
                      progressColor: _primary,
                      strokeWidth: 6,
                    ),
                  ),
                  Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(widget.progress * 100).toInt()}%',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.stage,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              widget.stage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade300,
              ),
            ),
            const SizedBox(height: 12),
            _buildStageDots(),
          ],
        );
      },
    );
  }

  Widget _buildStageDots() {
    final stages = ['Optimizing...', 'Uploading...', 'Saving...'];
    final currentIndex = stages.indexOf(widget.stage);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(stages.length, (i) {
        final active = i <= currentIndex;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? _primary : _trackColor,
          ),
        );
      }),
    );
  }

  Widget _buildSuccess() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 500),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: value,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _primary.withOpacity(0.2),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 72,
                    color: _primary,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Report Submitted',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your report has been submitted',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Paints a static track ring and a clockwise progress arc. No rotation.
class _ProgressRingPainter extends CustomPainter {
  _ProgressRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    this.strokeWidth = 6,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Full track ring (dark gray)
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc (sweeps clockwise from top, no rotation)
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    const startAngle = -math.pi / 2; // 12 o'clock
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter old) {
    return old.progress != progress;
  }
}

/// Simple retry dialog for failed uploads. Dark theme.
class RetryDialog extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  const RetryDialog({
    super.key,
    required this.errorMessage,
    required this.onRetry,
    required this.onCancel,
  });

  static const Color _primary = Color(0xFF00D9A3);
  static const Color _surface = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade400, size: 28),
          const SizedBox(width: 12),
          const Text('Upload Failed', style: TextStyle(color: Colors.white)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            errorMessage,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade300),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade900.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade300, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Please check your internet connection',
                    style: TextStyle(fontSize: 13, color: Colors.blue.shade300),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: Text(
            'Cancel',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
          ),
        ),
        ElevatedButton(
          onPressed: onRetry,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.black87,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Retry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
