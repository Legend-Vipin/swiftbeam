import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/device_model.dart';
import '../services/p2p_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/glass_container.dart';
import '../widgets/neon_button.dart';

import 'file_picker_screen.dart';

class DiscoveryScreen extends StatefulWidget {
  final Function(DiscoveredDevice)? onDeviceSelected;
  final List<SelectedFileItem>? filesToSend;
  final Function(String qrPayload, List<SelectedFileItem> files)?
      onStartTransfer;

  const DiscoveryScreen({
    super.key,
    this.onDeviceSelected,
    this.filesToSend,
    this.onStartTransfer,
  });

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanAnimationController;
  final TextEditingController _manualUrlController = TextEditingController();
  final SwiftBeamP2PService _p2pService = SwiftBeamP2PService();
  List<DiscoveredDevice> _devices = [];
  final bool _isCameraActive = !Platform.isLinux && !Platform.isWindows;
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    _scanAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _p2pService.startBleDiscovery();
    _p2pService.discoveredDevicesStream.listen((devices) {
      if (mounted) {
        setState(() {
          _devices = devices;
        });
      }
    });
  }

  @override
  void dispose() {
    _scanAnimationController.dispose();
    _manualUrlController.dispose();
    super.dispose();
  }

  void _handleQrDetect(String code) {
    if (_hasScanned || code.isEmpty) return;
    _hasScanned = true;

    if (widget.onStartTransfer != null) {
      widget.onStartTransfer!(code, widget.filesToSend ?? []);
    } else if (widget.onDeviceSelected != null) {
      final device = DiscoveredDevice(
        id: 'scanned-peer',
        name: 'Scanned Receiver Endpoint',
        platform: DevicePlatform.android,
        signalStrength: 0.98,
        ipAddress: code,
      );
      widget.onDeviceSelected!(device);
    }
  }

  void _handleManualConnect() {
    final url = _manualUrlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a valid receiver URL (e.g. http://192.168.1.25:8888)',
          ),
        ),
      );
      return;
    }
    if (widget.onStartTransfer != null) {
      widget.onStartTransfer!(url, widget.filesToSend ?? []);
    } else if (widget.onDeviceSelected != null) {
      final device = DiscoveredDevice(
        id: 'manual-peer',
        name: 'Manual Receiver Endpoint',
        platform: DevicePlatform.windows,
        signalStrength: 0.90,
        ipAddress: url,
      );
      widget.onDeviceSelected!(device);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SwiftBeamColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: SwiftBeamColors.backgroundAmbientGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Navigation Bar
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scan Receiver QR',
                          style: SwiftBeamTypography.headlineMedium,
                        ),
                        Text(
                          'Aim camera at Receiver QR code to connect',
                          style: SwiftBeamTypography.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Live Camera QR Viewfinder
                Center(
                  child: Container(
                    width: double.infinity,
                    height: 260,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: SwiftBeamColors.primaryCyan.withValues(
                          alpha: 0.6,
                        ),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: SwiftBeamColors.primaryCyan.withValues(
                            alpha: 0.25,
                          ),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_isCameraActive)
                            MobileScanner(
                              onDetect: (capture) {
                                final List<Barcode> barcodes = capture.barcodes;
                                for (final barcode in barcodes) {
                                  if (barcode.rawValue != null) {
                                    _handleQrDetect(barcode.rawValue!);
                                    break;
                                  }
                                }
                              },
                            )
                          else
                            Container(
                              color: Colors.black87,
                              child: const Center(
                                child: Icon(
                                  Icons.camera_alt_outlined,
                                  color: Colors.white38,
                                  size: 64,
                                ),
                              ),
                            ),

                          // Viewfinder Corner Highlights
                          Container(
                            margin: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: SwiftBeamColors.primaryCyan.withValues(
                                  alpha: 0.8,
                                ),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),

                          // Animated Scan Beam Line (165FPS High-Refresh Rate Isolated)
                          AnimatedBuilder(
                            animation: _scanAnimationController,
                            child: Container(
                              height: 3,
                              decoration: const BoxDecoration(
                                color: SwiftBeamColors.primaryCyan,
                                boxShadow: [
                                  BoxShadow(
                                    color: SwiftBeamColors.primaryCyan,
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                            builder: (context, child) {
                              return Positioned(
                                top:
                                    30 + (_scanAnimationController.value * 180),
                                left: 30,
                                right: 30,
                                child: RepaintBoundary(child: child!),
                              );
                            },
                          ),

                          // Camera overlay label
                          Positioned(
                            bottom: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.qr_code_scanner_rounded,
                                    color: SwiftBeamColors.primaryCyan,
                                    size: 16,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Auto-scanning QR Code...',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
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
                ),
                const SizedBox(height: 24),

                // Manual URL Fallback Section
                const Text(
                  'MANUAL CONNECTION OPTION',
                  style: SwiftBeamTypography.labelLarge,
                ),
                const SizedBox(height: 4),
                const Text(
                  'If QR scanning is unavailable, enter or paste the receiver URL:',
                  style: SwiftBeamTypography.bodyMedium,
                ),
                const SizedBox(height: 12),

                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  borderColor: SwiftBeamColors.accentPurple.withValues(
                    alpha: 0.4,
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _manualUrlController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.black.withValues(alpha: 0.3),
                          hintText: 'http://192.168.1.25:8888',
                          hintStyle: const TextStyle(color: Colors.white38),
                          prefixIcon: const Icon(
                            Icons.link_rounded,
                            color: SwiftBeamColors.accentPurple,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: SwiftBeamColors.accentPurple.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: SwiftBeamColors.accentPurple,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      NeonButton(
                        label: 'Connect via Manual URL',
                        icon: Icons.double_arrow_rounded,
                        height: 48,
                        onPressed: _handleManualConnect,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Ambient Discovered Peers (If any)
                if (_devices.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'AMBIENT PEERS (${_devices.length})',
                        style: SwiftBeamTypography.labelLarge,
                      ),
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: SwiftBeamColors.primaryCyan,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ..._devices.map(
                    (device) => Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: GlassContainer(
                        padding: const EdgeInsets.all(14),
                        onTap: widget.onDeviceSelected != null
                            ? () => widget.onDeviceSelected!(device)
                            : null,
                        child: Row(
                          children: [
                            Icon(device.platformIcon, color: Colors.white),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                device.name,
                                style: SwiftBeamTypography.titleMedium,
                              ),
                            ),
                            const Text(
                              'Tap to connect',
                              style: TextStyle(
                                color: SwiftBeamColors.primaryCyan,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
