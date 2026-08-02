import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/glass_container.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onSendPressed;
  final VoidCallback onReceivePressed;
  final VoidCallback onPermissionsPressed;

  const HomeScreen({
    super.key,
    required this.onSendPressed,
    required this.onReceivePressed,
    required this.onPermissionsPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: SwiftBeamColors.backgroundAmbientGradient,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: SwiftBeamColors.primaryCyan.withValues(
                            alpha: 0.15,
                          ),
                          border: Border.all(
                            color: SwiftBeamColors.primaryCyan.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/logo.png',
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.bolt_rounded,
                              color: SwiftBeamColors.primaryCyan,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SwiftBeam',
                            style: SwiftBeamTypography.titleLarge,
                          ),
                          Text(
                            'Ultra-fast P2P Transfer',
                            style: SwiftBeamTypography.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.shield_outlined,
                      color: Colors.white70,
                    ),
                    onPressed: onPermissionsPressed,
                    tooltip: 'Permissions',
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Central Visual / Connection Illustration
              Expanded(
                child: GlassContainer(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer glowing ring
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: SwiftBeamColors.primaryCyan.withValues(
                                    alpha: 0.25,
                                  ),
                                  blurRadius: 30,
                                  spreadRadius: 10,
                                ),
                                BoxShadow(
                                  color: SwiftBeamColors.accentPurple
                                      .withValues(alpha: 0.2),
                                  blurRadius: 40,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: SwiftBeamColors.primaryGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: SwiftBeamColors.primaryCyan.withValues(
                                    alpha: 0.4,
                                  ),
                                  blurRadius: 15,
                                ),
                              ],
                            ),
                            child: Center(
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/logo.png',
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.bolt_rounded,
                                    size: 64,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Ready to Beam',
                        style: SwiftBeamTypography.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'High-speed encrypted peer-to-peer file sharing via QUIC & Wi-Fi Direct',
                        textAlign: TextAlign.center,
                        style: SwiftBeamTypography.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Action Cards: Split SEND / RECEIVE
              Row(
                children: [
                  Expanded(
                    child: GlassContainer(
                      padding: const EdgeInsets.all(20),
                      onTap: onSendPressed,
                      borderColor: SwiftBeamColors.primaryCyan.withValues(
                        alpha: 0.4,
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: SwiftBeamColors.primaryCyan.withValues(
                                alpha: 0.15,
                              ),
                            ),
                            child: const Icon(
                              Icons.upload_rounded,
                              color: SwiftBeamColors.primaryCyan,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'SEND',
                            style: SwiftBeamTypography.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Share Files',
                            style: SwiftBeamTypography.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GlassContainer(
                      padding: const EdgeInsets.all(20),
                      onTap: onReceivePressed,
                      borderColor: SwiftBeamColors.accentPurple.withValues(
                        alpha: 0.4,
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: SwiftBeamColors.accentPurple.withValues(
                                alpha: 0.15,
                              ),
                            ),
                            child: const Icon(
                              Icons.download_rounded,
                              color: SwiftBeamColors.accentPurple,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'RECEIVE',
                            style: SwiftBeamTypography.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Scan & Accept',
                            style: SwiftBeamTypography.bodyMedium,
                          ),
                        ],
                      ),
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
}
