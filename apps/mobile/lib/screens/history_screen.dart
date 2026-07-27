import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/transfer_history.dart';
import '../providers/history_provider.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/glass_container.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  String _formatSize(int bytes) {
    if (bytes <= 0) return "0 B";
    final mbs = bytes / (1024 * 1024);
    if (mbs >= 1.0) {
      return "${mbs.toStringAsFixed(1)} MB";
    }
    final kbs = bytes / 1024;
    return "${kbs.toStringAsFixed(0)} KB";
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyList = ref.watch(historyProvider);

    return Container(
      decoration: const BoxDecoration(
        gradient: SwiftBeamColors.backgroundAmbientGradient,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Transfer History',
                          style: SwiftBeamTypography.headlineMedium),
                      SizedBox(height: 4),
                      Text('Past sent and received files over P2P network',
                          style: SwiftBeamTypography.bodyMedium),
                    ],
                  ),
                  if (historyList.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_rounded,
                          color: Color(0xFFFF5D73)),
                      tooltip: 'Clear All History',
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF111827),
                            title: const Text('Clear History?',
                                style: TextStyle(color: Colors.white)),
                            content: const Text(
                                'This will remove all transfer history records from this device.',
                                style: TextStyle(color: Colors.white70)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  ref
                                      .read(historyProvider.notifier)
                                      .clearHistory();
                                  Navigator.pop(ctx);
                                },
                                child: const Text('Clear All',
                                    style: TextStyle(color: Color(0xFFFF5D73))),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: historyList.isEmpty
                    ? const Center(
                        child: GlassContainer(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.history_toggle_off_rounded,
                                  color: Colors.white38, size: 48),
                              SizedBox(height: 12),
                              Text('No Transfers Saved Yet',
                                  style: SwiftBeamTypography.titleMedium),
                              SizedBox(height: 4),
                              Text(
                                'Files sent or received over SwiftBeam will automatically be saved here.',
                                textAlign: TextAlign.center,
                                style: SwiftBeamTypography.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: historyList.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = historyList[index];
                          final isSent =
                              item.direction == TransferDirection.send;
                          final isCompleted =
                              item.status == TransferStatus.completed;

                          final statusColor = isCompleted
                              ? const Color(0xFF00D97E)
                              : const Color(0xFFFF5D73);

                          return GlassContainer(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSent
                                        ? SwiftBeamColors.primaryCyan
                                            .withValues(alpha: 0.15)
                                        : SwiftBeamColors.accentPurple
                                            .withValues(alpha: 0.15),
                                  ),
                                  child: Icon(
                                    isSent
                                        ? Icons.upload_rounded
                                        : Icons.download_rounded,
                                    color: isSent
                                        ? SwiftBeamColors.primaryCyan
                                        : SwiftBeamColors.accentPurple,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.fileName,
                                        style: SwiftBeamTypography.titleMedium,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            _formatSize(item.fileSize),
                                            style: SwiftBeamTypography
                                                .bodyMedium
                                                .copyWith(
                                              color: Colors.white70,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(
                                                  alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              isCompleted
                                                  ? 'SUCCESS'
                                                  : 'FAILED',
                                              style: TextStyle(
                                                color: statusColor,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _formatDateTime(item.timestamp),
                                              style: SwiftBeamTypography
                                                  .bodyMedium,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded,
                                      color: Colors.white38, size: 18),
                                  onPressed: () {
                                    ref
                                        .read(historyProvider.notifier)
                                        .removeRecord(item.id);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
