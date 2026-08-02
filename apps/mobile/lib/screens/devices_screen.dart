import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/device_model.dart';
import '../providers/settings_provider.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/glass_container.dart';

class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(deviceSettingsProvider);
    final List<DiscoveredDevice> trustedDevices = [];

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
              const Text(
                'Paired Devices & Status',
                style: SwiftBeamTypography.headlineMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                'Manage trusted peer endpoints and local status',
                style: SwiftBeamTypography.bodyMedium,
              ),
              const SizedBox(height: 20),

              // Local Device Status Card
              GlassContainer(
                padding: const EdgeInsets.all(20),
                borderColor: SwiftBeamColors.primaryCyan.withValues(alpha: 0.4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: SwiftBeamColors.primaryCyan.withValues(
                          alpha: 0.15,
                        ),
                      ),
                      child: const Icon(
                        Icons.laptop_rounded,
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
                            'THIS DEVICE (LOCAL ENDPOINT)',
                            style: TextStyle(
                              color: SwiftBeamColors.primaryCyan,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  settings.deviceName,
                                  style: SwiftBeamTypography.titleMedium,
                                ),
                              ),
                              if (settings.isCustomName)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: SwiftBeamColors.accentPurple
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Custom',
                                    style: TextStyle(
                                      color: SwiftBeamColors.accentPurple,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            settings.realDeviceName.isNotEmpty
                                ? 'Identity: ${settings.realDeviceName} • Active'
                                : 'mDNS & QUIC Active • Ready to Beam',
                            style: SwiftBeamTypography.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit_rounded,
                        color: SwiftBeamColors.primaryCyan,
                      ),
                      tooltip: 'Edit Device Name',
                      onPressed: () =>
                          _showEditDeviceNameDialog(context, ref, settings),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'TRUSTED PEERS',
                style: SwiftBeamTypography.labelLarge,
              ),
              const SizedBox(height: 12),

              Expanded(
                child: trustedDevices.isEmpty
                    ? const Center(
                        child: GlassContainer(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.devices_other_rounded,
                                color: Colors.white38,
                                size: 48,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'No Paired Devices Yet',
                                style: SwiftBeamTypography.titleMedium,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Devices will automatically appear here once scanned or connected via mDNS/QR.',
                                textAlign: TextAlign.center,
                                style: SwiftBeamTypography.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: trustedDevices.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final device = trustedDevices[index];
                          return GlassContainer(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: SwiftBeamColors.surface,
                                  ),
                                  child: Icon(
                                    device.platformIcon,
                                    color: Colors.white,
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
                                        device.name,
                                        style: SwiftBeamTypography.titleMedium,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${device.ipAddress} • Connected',
                                        style: SwiftBeamTypography.bodyMedium,
                                      ),
                                    ],
                                  ),
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

  void _showEditDeviceNameDialog(
    BuildContext context,
    WidgetRef ref,
    DeviceSettings settings,
  ) {
    final controller = TextEditingController(text: settings.deviceName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: SwiftBeamColors.primaryCyan.withValues(alpha: 0.4),
          ),
        ),
        title: const Row(
          children: [
            Icon(Icons.edit_rounded, color: SwiftBeamColors.primaryCyan),
            SizedBox(width: 10),
            Text(
              'Edit Device Name',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter a custom broadcast name for mDNS discovery and P2P transfers:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            if (settings.realDeviceName.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Hardware identity: ${settings.realDeviceName}',
                style: const TextStyle(color: Colors.white38, fontSize: 11.5),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.black38,
                hintText: 'Device Name...',
                hintStyle: const TextStyle(color: Colors.white38),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: SwiftBeamColors.primaryCyan.withValues(alpha: 0.4),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: SwiftBeamColors.primaryCyan,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (settings.isCustomName)
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await ref
                    .read(deviceSettingsProvider.notifier)
                    .resetToRealName();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Device name reset to real device identity!',
                      ),
                    ),
                  );
                }
              },
              child: const Text(
                'Reset to Real',
                style: TextStyle(color: Colors.amber),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: SwiftBeamColors.primaryCyan,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                ref
                    .read(deviceSettingsProvider.notifier)
                    .updateDeviceName(newName);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Device name saved as "$newName"!'),
                    backgroundColor: SwiftBeamColors.successGreen,
                  ),
                );
              }
            },
            child: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
