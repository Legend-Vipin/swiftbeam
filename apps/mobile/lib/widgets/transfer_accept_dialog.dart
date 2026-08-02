import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/glass_container.dart';
import '../widgets/neon_button.dart';
import '../models/device_model.dart';

class TransferAcceptDialog extends StatelessWidget {
  final String senderName;
  final DevicePlatform senderPlatform;
  final String fileName;
  final int fileCount;
  final String formattedSize;
  final String estimatedTime;
  final String speedEstimate;

  const TransferAcceptDialog({
    super.key,
    required this.senderName,
    required this.senderPlatform,
    required this.fileName,
    required this.fileCount,
    required this.formattedSize,
    required this.estimatedTime,
    required this.speedEstimate,
  });

  static Future<bool> show(
    BuildContext context, {
    required String senderName,
    required DevicePlatform senderPlatform,
    required String fileName,
    required int fileCount,
    required String formattedSize,
    required String estimatedTime,
    required String speedEstimate,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TransferAcceptDialog(
        senderName: senderName,
        senderPlatform: senderPlatform,
        fileName: fileName,
        fileCount: fileCount,
        formattedSize: formattedSize,
        estimatedTime: estimatedTime,
        speedEstimate: speedEstimate,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    // Dummy device to get the correct icon
    final dummyDevice = DiscoveredDevice(
      id: '',
      name: '',
      platform: senderPlatform,
      signalStrength: 0,
      ipAddress: '',
    );

    return PopScope(
      canPop: false, // Prevent back button closing
      child: GlassContainer(
        padding: const EdgeInsets.all(24.0),
        borderRadius: 32.0,
        backgroundColor: SwiftBeamColors.background.withValues(alpha: 0.8),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with Sender Info
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: SwiftBeamColors.surface,
                    radius: 28,
                    child: Icon(
                      dummyDevice.platformIcon,
                      color: SwiftBeamColors.primaryCyan,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Incoming Transfer',
                          style: SwiftBeamTypography.bodyMedium,
                        ),
                        Text(
                          senderName,
                          style: SwiftBeamTypography.headlineMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Countdown Timer
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 30.0, end: 0.0),
                    duration: const Duration(seconds: 30),
                    onEnd: () {
                      if (Navigator.canPop(context)) {
                        Navigator.of(context).pop(false);
                      }
                    },
                    builder: (context, value, child) {
                      return SizedBox(
                        width: 48,
                        height: 48,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: value / 30.0,
                              color: SwiftBeamColors.primaryCyan,
                              backgroundColor: SwiftBeamColors.surface,
                              strokeWidth: 3,
                            ),
                            Text(
                              value.ceil().toString(),
                              style: SwiftBeamTypography.labelLarge,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // File Info Container
              GlassContainer(
                padding: const EdgeInsets.all(16.0),
                borderRadius: 20.0,
                backgroundColor: SwiftBeamColors.surface.withValues(alpha: 0.5),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.insert_drive_file_rounded,
                          color: SwiftBeamColors.accentPurple,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fileName,
                                style: SwiftBeamTypography.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                fileCount > 1
                                    ? '$fileCount files • $formattedSize'
                                    : formattedSize,
                                style: SwiftBeamTypography.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: Divider(color: Colors.white12, height: 1),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStat('Time', estimatedTime, Icons.timer_outlined),
                        _buildStat('Speed', speedEstimate, Icons.speed_rounded),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Security Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    color: SwiftBeamColors.successGreen,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'End-to-End Encrypted (ChaCha20)',
                    style: SwiftBeamTypography.bodyMedium.copyWith(
                      color: SwiftBeamColors.successGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(
                          color: SwiftBeamColors.dangerRed,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        'Reject',
                        style: SwiftBeamTypography.labelLarge.copyWith(
                          color: SwiftBeamColors.dangerRed,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: NeonButton(
                      label: 'Accept',
                      icon: Icons.check_circle_outline_rounded,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 16),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: SwiftBeamTypography.bodyMedium),
            Text(value, style: SwiftBeamTypography.titleMedium),
          ],
        ),
      ],
    );
  }
}
