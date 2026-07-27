import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/permission_utils.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/glass_container.dart';
import '../widgets/neon_button.dart';

class PermissionItem {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  bool isGranted;

  PermissionItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.isGranted = false,
  });
}

class PermissionsScreen extends StatefulWidget {
  final VoidCallback onContinue;

  const PermissionsScreen({super.key, required this.onContinue});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  final List<PermissionItem> _permissions = [
    PermissionItem(
      id: 'wifi',
      title: 'Wi-Fi & Direct',
      subtitle: 'Required for high-speed local P2P transfer sockets',
      icon: Icons.wifi_rounded,
      isGranted: true,
    ),
    PermissionItem(
      id: 'ble',
      title: 'Bluetooth LE',
      subtitle: 'Discovers nearby peers without manual IP configuration',
      icon: Icons.bluetooth_rounded,
      isGranted: false,
    ),
    PermissionItem(
      id: 'nearby',
      title: 'Nearby Devices',
      subtitle: 'Enables cross-platform mDNS radar scanning',
      icon: Icons.cell_tower_rounded,
      isGranted: false,
    ),
    PermissionItem(
      id: 'storage',
      title: 'Storage Access',
      subtitle: 'Permission to save incoming files and select media',
      icon: Icons.folder_rounded,
      isGranted: true,
    ),
    PermissionItem(
      id: 'notifications',
      title: 'Notifications',
      subtitle: 'Shows live transfer progress in status bar',
      icon: Icons.notifications_active_rounded,
      isGranted: false,
    ),
  ];

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
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    const Text('Required Permissions',
                        style: SwiftBeamTypography.headlineMedium),
                  ],
                ),
                const SizedBox(width: 8),
                const Padding(
                  padding: EdgeInsets.only(left: 8.0, top: 4.0),
                  child: Text(
                    'SwiftBeam uses local direct connections. No personal data is stored or uploaded to servers.',
                    style: SwiftBeamTypography.bodyLarge,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.separated(
                    itemCount: _permissions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final item = _permissions[index];
                      return GlassContainer(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: item.isGranted
                                    ? SwiftBeamColors.successGreen
                                        .withValues(alpha: 0.15)
                                    : SwiftBeamColors.primaryCyan
                                        .withValues(alpha: 0.15),
                              ),
                              child: Icon(
                                item.icon,
                                color: item.isGranted
                                    ? SwiftBeamColors.successGreen
                                    : SwiftBeamColors.primaryCyan,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.title,
                                      style: SwiftBeamTypography.titleMedium),
                                  const SizedBox(height: 2),
                                  Text(item.subtitle,
                                      style: SwiftBeamTypography.bodyMedium),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: item.isGranted
                                    ? SwiftBeamColors.successGreen
                                        .withValues(alpha: 0.2)
                                    : SwiftBeamColors.primaryCyan,
                                foregroundColor: item.isGranted
                                    ? SwiftBeamColors.successGreen
                                    : SwiftBeamColors.background,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: item.isGranted
                                        ? SwiftBeamColors.successGreen
                                        : Colors.transparent,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                              ),
                              onPressed: () async {
                                if (kIsWeb ||
                                    Platform.isLinux ||
                                    Platform.isWindows ||
                                    Platform.isMacOS) {
                                  setState(() {
                                    item.isGranted = true;
                                  });
                                  return;
                                }

                                if (item.id == 'wifi') {
                                  await Permission.nearbyWifiDevices.request();
                                } else if (item.id == 'ble') {
                                  await [
                                    Permission.bluetoothScan,
                                    Permission.bluetoothConnect,
                                    Permission.bluetoothAdvertise,
                                    Permission.bluetooth
                                  ].request();
                                } else if (item.id == 'nearby') {
                                  await Permission.location.request();
                                } else if (item.id == 'storage') {
                                  await [
                                    Permission.storage,
                                    Permission.manageExternalStorage
                                  ].request();
                                } else if (item.id == 'notifications') {
                                  await Permission.notification.request();
                                }

                                bool granted = false;
                                if (item.id == 'wifi') {
                                  granted =
                                      await SafePermissionHandler.isGranted(
                                          Permission.nearbyWifiDevices);
                                } else if (item.id == 'ble') {
                                  granted =
                                      await SafePermissionHandler.isGranted(
                                              Permission.bluetoothConnect) ||
                                          await SafePermissionHandler.isGranted(
                                              Permission.bluetooth);
                                } else if (item.id == 'nearby') {
                                  granted =
                                      await SafePermissionHandler.isGranted(
                                          Permission.location);
                                } else if (item.id == 'storage') {
                                  granted =
                                      await SafePermissionHandler.isGranted(
                                              Permission.storage) ||
                                          await SafePermissionHandler.isGranted(
                                              Permission.manageExternalStorage);
                                } else if (item.id == 'notifications') {
                                  granted =
                                      await SafePermissionHandler.isGranted(
                                          Permission.notification);
                                }

                                setState(() {
                                  item.isGranted = granted;
                                });
                              },
                              child: item.isGranted
                                  ? const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_rounded, size: 18),
                                        SizedBox(width: 4),
                                        Text('Granted',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold)),
                                      ],
                                    )
                                  : const Text('Grant',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                NeonButton(
                  label: 'Continue to Discovery',
                  onPressed: widget.onContinue,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
