import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

/// Clean minimal futuristic upload progress overlay
class UploadProgressOverlay extends StatefulWidget {
  final double progress; // 0.0 to 1.0
  final String stage; // "Optimizing image...", "Uploading...", "Success!"
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
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const Color primaryGradientStart = Color(0xFF6C63FF);
  static const Color primaryGradientEnd = Color(0xFF4ECDC4);
  static const Color successColor = Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    
    // Rotation for ring animation
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    // Pulse for scale animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        color: Colors.black.withOpacity(0.4),
        child: Center(
          child: AnimationConfiguration.synchronized(
            duration: const Duration(milliseconds: 400),
            child: ScaleAnimation(
              child: FadeInAnimation(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 40,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!widget.showSuccess) ...[
                        // Futuristic progress ring
                        AnimatedBuilder(
                          animation: Listenable.merge([_rotationController, _pulseAnimation]),
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _pulseAnimation.value,
                              child: Transform.rotate(
                                angle: _rotationController.value * 2 * 3.14159,
                                child: SizedBox(
                                  width: 140,
                                  height: 140,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Background ring
                                      SizedBox(
                                        width: 140,
                                        height: 140,
                                        child: CircularProgressIndicator(
                                          value: 1.0,
                                          strokeWidth: 6,
                                          backgroundColor: Colors.transparent,
                                          valueColor: AlwaysStoppedAnimation(
                                            Colors.grey.shade100,
                                          ),
                                        ),
                                      ),
                                      // Gradient progress ring
                                      SizedBox(
                                        width: 140,
                                        height: 140,
                                        child: ShaderMask(
                                          shaderCallback: (bounds) {
                                            return LinearGradient(
                                              colors: const [
                                                primaryGradientStart,
                                                primaryGradientEnd,
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ).createShader(bounds);
                                          },
                                          child: CircularProgressIndicator(
                                            value: widget.progress,
                                            strokeWidth: 6,
                                            strokeCap: StrokeCap.round,
                                            backgroundColor: Colors.transparent,
                                            valueColor: const AlwaysStoppedAnimation(
                                              Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Percentage text
                                      Container(
                                        width: 110,
                                        height: 110,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.grey.shade50,
                                        ),
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              ShaderMask(
                                                shaderCallback: (bounds) {
                                                  return const LinearGradient(
                                                    colors: [
                                                      primaryGradientStart,
                                                      primaryGradientEnd,
                                                    ],
                                                  ).createShader(bounds);
                                                },
                                                child: Text(
                                                  '${(widget.progress * 100).toInt()}%',
                                                  style: const TextStyle(
                                                    fontSize: 32,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Uploading',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.grey.shade500,
                                                  letterSpacing: 1.2,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 28),
                        // Stage text
                        Text(
                          widget.stage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Speed/status indicator
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: primaryGradientStart,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Processing...',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // Success animation
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 600),
                          tween: Tween(begin: 0.0, end: 1.0),
                          curve: Curves.elasticOut,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      successColor.withOpacity(0.1),
                                      successColor.withOpacity(0.05),
                                    ],
                                  ),
                                ),
                                child: const Icon(
                                  Icons.check_circle_rounded,
                                  size: 80,
                                  color: successColor,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          'Upload Complete!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your report has been submitted',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Simple retry dialog for failed uploads
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade400, size: 28),
          const SizedBox(width: 12),
          const Text('Upload Failed'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            errorMessage,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Please check your internet connection',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue.shade700,
                    ),
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
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
        ),
        ElevatedButton(
          onPressed: onRetry,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C63FF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Retry',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
