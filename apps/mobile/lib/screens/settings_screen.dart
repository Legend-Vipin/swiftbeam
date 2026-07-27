import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/glass_container.dart';
import '../widgets/neon_button.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final currentName = ref.read(deviceSettingsProvider).deviceName;
    _nameController = TextEditingController(text: currentName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<DeviceSettings>(deviceSettingsProvider, (previous, next) {
      if (previous?.deviceName != next.deviceName &&
          _nameController.text != next.deviceName) {
        _nameController.text = next.deviceName;
      }
    });

    final settings = ref.watch(deviceSettingsProvider);

    return Container(
      decoration: const BoxDecoration(
        gradient: SwiftBeamColors.backgroundAmbientGradient,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Settings & Configuration',
                  style: SwiftBeamTypography.headlineMedium),
              const SizedBox(height: 4),
              const Text(
                  'Configure device identity, protocol fallbacks, and storage paths',
                  style: SwiftBeamTypography.bodyMedium),
              const SizedBox(height: 24),

              // Customize Device Name Card
              const Text('DEVICE IDENTITY',
                  style: SwiftBeamTypography.labelLarge),
              const SizedBox(height: 10),
              GlassContainer(
                padding: const EdgeInsets.all(20),
                borderColor: SwiftBeamColors.primaryCyan.withValues(alpha: 0.4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Custom Device Name',
                            style: SwiftBeamTypography.titleMedium),
                        if (settings.isCustomName)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: SwiftBeamColors.accentPurple
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: SwiftBeamColors.accentPurple
                                      .withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              'Customized',
                              style: TextStyle(
                                  color: SwiftBeamColors.accentPurple,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                        'This name is broadcasted to nearby peers via mDNS & BLE radar.',
                        style: SwiftBeamTypography.bodyMedium),
                    if (settings.realDeviceName.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.memory_rounded,
                              color: Colors.white54, size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Hardware/OS Identity: ${settings.realDeviceName}',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.black.withValues(alpha: 0.3),
                        hintText: 'Enter device name...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(Icons.edit_rounded,
                            color: SwiftBeamColors.primaryCyan),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color: SwiftBeamColors.primaryCyan
                                  .withValues(alpha: 0.4)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: SwiftBeamColors.primaryCyan, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: NeonButton(
                            label: 'Save Device Name',
                            icon: Icons.save_rounded,
                            height: 48,
                            onPressed: () {
                              final text = _nameController.text.trim();
                              if (text.isNotEmpty) {
                                ref
                                    .read(deviceSettingsProvider.notifier)
                                    .updateDeviceName(text);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text('Device name updated to "$text"!'),
                                    backgroundColor:
                                        SwiftBeamColors.successGreen,
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                        if (settings.isCustomName) ...[
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.3)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            icon: const Icon(Icons.restart_alt_rounded,
                                color: Colors.white70, size: 20),
                            label: const Text('Reset',
                                style: TextStyle(color: Colors.white70)),
                            onPressed: () async {
                              await ref
                                  .read(deviceSettingsProvider.notifier)
                                  .resetToRealName();
                              _nameController.text =
                                  ref.read(deviceSettingsProvider).deviceName;
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Device name reset to real device identity!'),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Preferences & Toggles Card
              const Text('PREFERENCES', style: SwiftBeamTypography.labelLarge),
              const SizedBox(height: 10),
              GlassContainer(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SwitchListTile(
                      activeTrackColor: SwiftBeamColors.primaryCyan,
                      title: const Text('Auto-accept Trusted Peers',
                          style: SwiftBeamTypography.titleMedium),
                      subtitle: const Text(
                          'Skip confirmation prompt for paired devices',
                          style: SwiftBeamTypography.bodyMedium),
                      value: settings.autoAcceptTrusted,
                      onChanged: (val) {
                        ref
                            .read(deviceSettingsProvider.notifier)
                            .toggleAutoAccept(val);
                      },
                    ),
                    const Divider(color: Colors.white10),
                    ListTile(
                      leading: const Icon(Icons.folder_special_rounded,
                          color: SwiftBeamColors.primaryCyan),
                      title: const Text('Download Location',
                          style: SwiftBeamTypography.titleMedium),
                      subtitle: Text(settings.downloadDirectory,
                          style: SwiftBeamTypography.bodyMedium),
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: Colors.white54),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Network Protocol Card
              const Text('NETWORK PROTOCOL',
                  style: SwiftBeamTypography.labelLarge),
              const SizedBox(height: 10),
              const GlassContainer(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.speed_rounded,
                          color: SwiftBeamColors.accentPurple),
                      title: Text('QUIC Core Transport',
                          style: SwiftBeamTypography.titleMedium),
                      subtitle: Text(
                          'Quinn UDP with ChaCha20-Poly1305 encryption',
                          style: SwiftBeamTypography.bodyMedium),
                      trailing: Text('Active',
                          style: TextStyle(
                              color: SwiftBeamColors.successGreen,
                              fontWeight: FontWeight.bold)),
                    ),
                    Divider(color: Colors.white10),
                    ListTile(
                      leading: Icon(Icons.web_rounded,
                          color: SwiftBeamColors.primaryCyan),
                      title: Text('Web Portal Fallback',
                          style: SwiftBeamTypography.titleMedium),
                      subtitle: Text(
                          'HTTP server port 8888 for no-app browser transfers',
                          style: SwiftBeamTypography.bodyMedium),
                      trailing: Text('Enabled',
                          style: TextStyle(
                              color: SwiftBeamColors.primaryCyan,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // About SwiftBeam Card
              const Text('ABOUT SWIFTBEAM',
                  style: SwiftBeamTypography.labelLarge),
              const SizedBox(height: 10),
              GlassContainer(
                padding: const EdgeInsets.all(20),
                borderColor:
                    SwiftBeamColors.accentPurple.withValues(alpha: 0.4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: SwiftBeamColors.accentPurple, size: 28),
                        SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SwiftBeam P2P',
                                style: SwiftBeamTypography.titleLarge),
                            Text('Version 1.0.0 (Enterprise Build)',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Icon(Icons.code_rounded,
                            color: SwiftBeamColors.primaryCyan, size: 20),
                        SizedBox(width: 10),
                        Text('Developer:',
                            style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.bold)),
                        SizedBox(width: 6),
                        Text('Legend-Vipin',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Icon(Icons.link_rounded,
                            color: SwiftBeamColors.primaryCyan, size: 20),
                        SizedBox(width: 10),
                        Text('Repository:',
                            style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: SwiftBeamColors.primaryCyan
                                .withValues(alpha: 0.3)),
                      ),
                      child: const SelectableText(
                        'https://github.com/Legend-Vipin/swiftbeam',
                        style: TextStyle(
                          color: SwiftBeamColors.primaryCyan,
                          fontSize: 13,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
