import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/glass_container.dart';
import '../widgets/neon_button.dart';

class TransferCompleteScreen extends StatelessWidget {
  final VoidCallback onSendAgain;
  final VoidCallback onOpenFolder;
  final String summaryText;

  const TransferCompleteScreen({
    super.key,
    required this.onSendAgain,
    required this.onOpenFolder,
    this.summaryText =
        'All payload chunks were securely transferred and verified.',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SwiftBeamColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: SwiftBeamColors.backgroundAmbientGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // Glowing Success Badge
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: SwiftBeamColors.successGreen.withValues(alpha: 0.15),
                    border: Border.all(
                        color: SwiftBeamColors.successGreen, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color:
                            SwiftBeamColors.successGreen.withValues(alpha: 0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: SwiftBeamColors.successGreen,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 28),

                const Text('Transfer Complete!',
                    style: SwiftBeamTypography.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  summaryText,
                  textAlign: TextAlign.center,
                  style: SwiftBeamTypography.bodyLarge,
                ),
                const SizedBox(height: 32),

                // Transfer Summary Stats Card
                GlassContainer(
                  padding: const EdgeInsets.all(20),
                  borderColor:
                      SwiftBeamColors.successGreen.withValues(alpha: 0.3),
                  child: const Column(
                    children: [
                      _StatRow(
                          label: 'Transport Protocol',
                          value: 'QUIC / UDP Direct'),
                      Divider(color: Colors.white10),
                      _StatRow(
                          label: 'Cipher Spec',
                          value: 'ChaCha20-Poly1305 AEAD'),
                      Divider(color: Colors.white10),
                      _StatRow(
                          label: 'Verification Integrity',
                          value: 'BLAKE3 Hash Verified 100%'),
                    ],
                  ),
                ),

                const Spacer(),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(
                              color: Colors.white30, width: 1.5),
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: onOpenFolder,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open_rounded, size: 20),
                            SizedBox(width: 8),
                            Text('Open Folder',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: NeonButton(
                        label: 'Send Again',
                        icon: Icons.refresh_rounded,
                        onPressed: onSendAgain,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: SwiftBeamTypography.bodyMedium),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
