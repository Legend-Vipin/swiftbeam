import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/transfer_provider.dart';

class TransferListWidget extends ConsumerWidget {
  const TransferListWidget({super.key});

  String _formatSpeed(int bytesPerSec) {
    final mbs = bytesPerSec / (1024 * 1024);
    return "${mbs.toStringAsFixed(2)} MB/s";
  }

  String _formatEta(int seconds) {
    if (seconds <= 0 || seconds >= 3600) return "--:--";
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  String _formatSize(int bytes) {
    final mbs = bytes / (1024 * 1024);
    if (mbs >= 1.0) {
      return "${mbs.toStringAsFixed(1)} MB";
    }
    final kbs = bytes / 1024;
    return "${kbs.toStringAsFixed(0)} KB";
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transfers = ref.watch(transferListProvider);

    if (transfers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.swap_horizontal_circle_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'No active file transfers',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transfers.length,
      itemBuilder: (context, index) {
        final transfer = transfers.values.elementAt(index);
        final progressPercent = (transfer.progress * 100).toStringAsFixed(0);

        Color statusColor;
        Color accentGlow;
        String statusLabel;
        Widget statusIcon;

        switch (transfer.status) {
          case 'completed':
            statusColor = const Color(0xFF00D97E);
            accentGlow = const Color(0xFF00D97E).withValues(alpha: 0.25);
            statusLabel = "Completed";
            statusIcon = const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF00D97E),
              size: 24,
            );
            break;
          case 'failed':
            statusColor = const Color(0xFFFF5D73);
            accentGlow = const Color(0xFFFF5D73).withValues(alpha: 0.25);
            statusLabel = "Failed";
            statusIcon = const Icon(
              Icons.error_rounded,
              color: Color(0xFFFF5D73),
              size: 24,
            );
            break;
          case 'paused':
            statusColor = const Color(0xFFAE6BFF);
            accentGlow = const Color(0xFFAE6BFF).withValues(alpha: 0.25);
            statusLabel = "Paused";
            statusIcon = const Icon(
              Icons.pause_circle_rounded,
              color: Color(0xFFAE6BFF),
              size: 24,
            );
            break;
          case 'cancelled':
            statusColor = Colors.white38;
            accentGlow = Colors.transparent;
            statusLabel = "Cancelled";
            statusIcon = const Icon(
              Icons.block_rounded,
              color: Colors.white38,
              size: 24,
            );
            break;
          case 'started':
          case 'progressing':
          default:
            statusColor = const Color(0xFF00D9FF);
            accentGlow = const Color(0xFF00D9FF).withValues(alpha: 0.3);
            statusLabel = "Sharing Live...";
            statusIcon = const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.8,
                color: Color(0xFF00D9FF),
              ),
            );
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF111827).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: accentGlow,
                blurRadius: 20,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: statusColor.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Badge & File Name
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: statusIcon,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transfer.fileName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16.5,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_formatSize(transfer.bytesTransferred)} / ${_formatSize(transfer.totalSize)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$progressPercent%',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: statusColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Neon Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: transfer.progress,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  color: statusColor,
                  minHeight: 10,
                ),
              ),

              const SizedBox(height: 16),

              // Quick Share / ShareMe Metrics Dashboard Card
              if (transfer.status == 'progressing' ||
                  transfer.status == 'started') ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Speed Metric
                      Row(
                        children: [
                          const Icon(
                            Icons.bolt_rounded,
                            color: Color(0xFF00D9FF),
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'SPEED',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                _formatSpeed(transfer.speedBps),
                                style: const TextStyle(
                                  color: Color(0xFF00D9FF),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Divider
                      Container(height: 24, width: 1, color: Colors.white12),
                      // ETA Metric
                      Row(
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            color: Color(0xFF34D399),
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'EST. TIME',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                _formatEta(transfer.etaSeconds),
                                style: const TextStyle(
                                  color: Color(0xFF34D399),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Divider
                      Container(height: 24, width: 1, color: Colors.white12),
                      // Encryption Badge
                      const Row(
                        children: [
                          Icon(
                            Icons.security_rounded,
                            color: Color(0xFFAE6BFF),
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'P2P QUIC',
                            style: TextStyle(
                              color: Color(0xFFAE6BFF),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              // Action Buttons & Controls
              if (transfer.status != 'completed') ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (transfer.status == 'progressing' ||
                        transfer.status == 'started') ...[
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFAE6BFF),
                          backgroundColor: const Color(
                            0xFFAE6BFF,
                          ).withValues(alpha: 0.12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.pause_circle_rounded, size: 18),
                        label: const Text(
                          'Pause',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        onPressed: () => ref
                            .read(transferListProvider.notifier)
                            .pauseTransfer(transfer.transferId),
                      ),
                      const SizedBox(width: 10),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFFF5D73),
                          backgroundColor: const Color(
                            0xFFFF5D73,
                          ).withValues(alpha: 0.12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.cancel_rounded, size: 18),
                        label: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        onPressed: () => ref
                            .read(transferListProvider.notifier)
                            .cancelTransfer(transfer.transferId),
                      ),
                    ] else if (transfer.status == 'paused') ...[
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF00D9FF),
                          backgroundColor: const Color(
                            0xFF00D9FF,
                          ).withValues(alpha: 0.12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.play_circle_rounded, size: 18),
                        label: const Text(
                          'Resume',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        onPressed: () => ref
                            .read(transferListProvider.notifier)
                            .resumeTransfer(transfer.transferId),
                      ),
                      const SizedBox(width: 10),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFFF5D73),
                          backgroundColor: const Color(
                            0xFFFF5D73,
                          ).withValues(alpha: 0.12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.cancel_rounded, size: 18),
                        label: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        onPressed: () => ref
                            .read(transferListProvider.notifier)
                            .cancelTransfer(transfer.transferId),
                      ),
                    ] else if (transfer.status == 'failed' ||
                        transfer.status == 'cancelled') ...[
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFFFB84D),
                          backgroundColor: const Color(
                            0xFFFFB84D,
                          ).withValues(alpha: 0.12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text(
                          'Retry',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        onPressed: () => ref
                            .read(transferListProvider.notifier)
                            .retryTransfer(transfer.transferId),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(Icons.delete_rounded),
                        color: Colors.white38,
                        iconSize: 20,
                        onPressed: () => ref
                            .read(transferListProvider.notifier)
                            .removeTransfer(transfer.transferId),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
