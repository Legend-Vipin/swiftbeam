import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/transfer_provider.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/glass_container.dart';
import '../widgets/neon_button.dart';
import '../widgets/transfer_widget.dart';

class TransferDashboardScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;
  final String fileName;
  final double totalSizeMB;

  const TransferDashboardScreen({
    super.key,
    required this.onComplete,
    this.fileName = 'Active File Transfer',
    this.totalSizeMB = 0.0,
  });

  @override
  ConsumerState<TransferDashboardScreen> createState() =>
      _TransferDashboardScreenState();
}

class _TransferDashboardScreenState
    extends ConsumerState<TransferDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // If a specific single file was passed to constructor and provider is empty, initialize fallback entry
    Future.microtask(() {
      final transfers = ref.read(transferListProvider);
      if (transfers.isEmpty && widget.totalSizeMB > 0) {
        ref.read(transferListProvider.notifier).addTransfer(
              TransferProgress(
                transferId: 'tx_${DateTime.now().millisecondsSinceEpoch}',
                fileName: widget.fileName,
                totalSize: (widget.totalSizeMB * 1024 * 1024).toInt(),
                status: 'started',
              ),
            );
      }
    });
  }

  String _calculateTotalSpeed(Map<String, TransferProgress> transfers) {
    int totalSpeedBps = 0;
    for (final t in transfers.values) {
      if (t.status == 'progressing') {
        totalSpeedBps += t.speedBps;
      }
    }
    final mbs = totalSpeedBps / (1024 * 1024);
    return "${mbs.toStringAsFixed(2)} MB/s";
  }

  @override
  Widget build(BuildContext context) {
    final transfers = ref.watch(transferListProvider);
    final activeCount = transfers.values
        .where((t) => t.status == 'progressing' || t.status == 'started')
        .length;
    final totalSpeedStr = _calculateTotalSpeed(transfers);

    return Scaffold(
      backgroundColor: SwiftBeamColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: SwiftBeamColors.backgroundAmbientGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dashboard Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Transfer Dashboard',
                              style: SwiftBeamTypography.headlineMedium),
                          Text(
                            activeCount > 0
                                ? '$activeCount active transfer(s)'
                                : 'File Transfer Status',
                            style: SwiftBeamTypography.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color:
                            SwiftBeamColors.primaryCyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: SwiftBeamColors.primaryCyan
                                .withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.speed_rounded,
                              color: SwiftBeamColors.primaryCyan, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            totalSpeedStr,
                            style: const TextStyle(
                              color: SwiftBeamColors.primaryCyan,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Transfer Security Badge Card
                const GlassContainer(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.shield_rounded,
                              color: SwiftBeamColors.successGreen, size: 20),
                          SizedBox(width: 8),
                          Text('ChaCha20-Poly1305 Encrypted',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                      Text('QUIC P2P Direct',
                          style: TextStyle(
                              color: SwiftBeamColors.accentPurple,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // File Transfer List Format Container
                const Expanded(
                  child: SingleChildScrollView(
                    physics: BouncingScrollPhysics(),
                    child: TransferListWidget(),
                  ),
                ),
                const SizedBox(height: 16),

                // Navigation Action Button
                NeonButton(
                  label:
                      activeCount > 0 ? 'Complete Transfer' : 'Return to Home',
                  icon: activeCount > 0
                      ? Icons.check_circle_rounded
                      : Icons.home_rounded,
                  onPressed: widget.onComplete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
