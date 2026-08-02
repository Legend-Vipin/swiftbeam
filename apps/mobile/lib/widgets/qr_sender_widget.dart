import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path/path.dart' as p;
import '../services/web_portal_service.dart';
import '../services/app_initialization_service.dart';
import '../core/ffi/api.dart';
import '../providers/transfer_provider.dart';
import '../domain/models/transfer_history.dart';
import 'transfer_widget.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class QRSenderWidget extends ConsumerStatefulWidget {
  const QRSenderWidget({super.key});

  @override
  ConsumerState<QRSenderWidget> createState() => _QRSenderWidgetState();
}

class _QRSenderWidgetState extends ConsumerState<QRSenderWidget> {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  bool _isProcessing = false;
  bool _isBluetoothAvailable = true;
  String? _selectedFilePath;
  String? _selectedFileName;
  StreamSubscription<String>? _ffiSubscription;

  // Web Portal Share state
  final WebPortalService _webPortalService = WebPortalService();
  String? _webShareUri;
  String? _manualShareUrl;
  String? _sharedFileName;

  @override
  void initState() {
    super.initState();
    _checkBluetoothStatus();
    // Start browsing for nearby devices via mDNS automatically
    ref.read(peerDiscoveryProvider.notifier).start();
  }

  Future<void> _checkBluetoothStatus() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        if (await FlutterBluePlus.adapterState.first ==
            BluetoothAdapterState.off) {
          await FlutterBluePlus.turnOn();
        }
      } catch (e) {
        debugPrint("Sender Bluetooth non-fatal notification: $e");
        if (mounted) {
          setState(() {
            _isBluetoothAvailable = false;
          });
        }
      }
    }
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final rawValue = barcode.rawValue ?? barcode.displayValue;
      if (rawValue == null || rawValue.isEmpty) continue;

      String? targetPayload;

      // 1. URL containing ?data= or &data=
      if (rawValue.contains('data=')) {
        try {
          final uri = Uri.parse(rawValue);
          targetPayload = uri.queryParameters['data'] ?? rawValue;
        } catch (_) {
          targetPayload = rawValue;
        }
      }
      // 2. Direct HTTP URL or JSON string
      else if (rawValue.startsWith('http://') ||
          rawValue.startsWith('https://') ||
          rawValue.startsWith('{')) {
        targetPayload = rawValue;
      }

      if (targetPayload != null) {
        if (_selectedFilePath == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'File required! Please select a file to send using "Select File to Send" button above.',
                ),
                duration: Duration(seconds: 3),
              ),
            );
          }
          break;
        }

        setState(() {
          _isProcessing = true;
        });
        await _connectAndSend(rawValue);
        break;
      }
    }
  }

  List<String> _selectedFilePaths = [];

  // Choose file via FilePicker (allows multiple files)
  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;

      final validPaths = result.files
          .where((f) => f.path != null)
          .map((f) => f.path!)
          .toList();

      if (validPaths.isEmpty) return;

      setState(() {
        _selectedFilePaths = validPaths;
        _selectedFilePath = validPaths.first;
        _selectedFileName = validPaths.length == 1
            ? p.basename(validPaths.first)
            : '${validPaths.length} Files Selected';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick file: $e')));
      }
    }
  }

  // Connect and Send using standard FFI connectToQr
  Future<void> _connectAndSend(String qrJsonOrUri) async {
    try {
      if (!AppInitializationService.isInitialized) {
        await AppInitializationService.initialize();
      }

      String qrJson = qrJsonOrUri;
      if (qrJsonOrUri.contains('data=')) {
        try {
          final uri = Uri.parse(qrJsonOrUri);
          final base64Payload = uri.queryParameters['data'] ?? '';
          if (base64Payload.isNotEmpty) {
            String normalized = base64Payload.replaceAll(' ', '+');
            while (normalized.length % 4 != 0) {
              normalized += '=';
            }
            qrJson = utf8.decode(base64Decode(normalized));
          }
        } catch (e) {
          debugPrint("Base64 decode fallback, passing raw: $e");
          qrJson = qrJsonOrUri;
        }
      }

      final ffiStream = connectToQr(
        qrJson: qrJson,
        filePath: _selectedFilePath!,
      );

      _ffiSubscription = ffiStream.listen(
        (event) {
          ref
              .read(transferListProvider.notifier)
              .handleFfiEventJson(event, direction: TransferDirection.send);
        },
        onError: (err) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Transfer failed: $err')));
          }
          setState(() {
            _isProcessing = false;
          });
        },
        onDone: () {
          setState(() {
            _isProcessing = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Connection failed: $e')));
      }
    }
  }

  // Direct connection to a peer discovered via mDNS (App-to-App connection)
  Future<void> _sendToMdnsPeer(DiscoveredPeer peer) async {
    if (_selectedFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file to send first!')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    // Construct QR JSON configuration using resolved mDNS details
    final mdnsQrPayload = jsonEncode({
      "device_id": peer.deviceName,
      "session": "MDNS_${peer.peerId}",
      "ip": peer.ip.isNotEmpty ? peer.ip : "127.0.0.1",
      "port": peer.port,
      "token": "MDNS_TOKEN",
      "pub_key": "", // Key exchange happens dynamically in-band
      "expires": (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600,
      "version": "1.0",
    });

    await _connectAndSend(mdnsQrPayload);
  }

  // Start the Web Server for local sharing (No App fallback)
  Future<void> _startWebShare() async {
    final pathsToShare = _selectedFilePaths.isNotEmpty
        ? _selectedFilePaths
        : (_selectedFilePath != null ? [_selectedFilePath!] : <String>[]);

    if (pathsToShare.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select files to share first!')),
      );
      return;
    }

    try {
      setState(() {
        _isProcessing = true;
      });

      final port = await _webPortalService.start(sharedFilePaths: pathsToShare);
      final ip = await _webPortalService.getLocalIpAddress();

      // Encode metadata inside query parameter so that if they do have the app, it can scan it
      final webMetaPayload = jsonEncode({
        "device_id": "SwiftBeam Web Portal",
        "session": "WEB_${DateTime.now().millisecondsSinceEpoch}",
        "ip": ip,
        "port": port,
        "token": "WEB_TOKEN",
        "pub_key": "KEY_EXCHANGE_IN_BAND",
        "expires": (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600,
        "version": "1.0",
      });
      final base64Meta = base64Encode(utf8.encode(webMetaPayload));

      setState(() {
        _webShareUri = 'http://$ip:$port/download?data=$base64Meta';
        _manualShareUrl = 'http://$ip:$port';
        _sharedFileName = _selectedFileName;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Web sharing failed to start: $e')),
        );
      }
    }
  }

  Future<void> _stopWebShare() async {
    await _webPortalService.stop();
    setState(() {
      _webShareUri = null;
      _manualShareUrl = null;
      _sharedFileName = null;
    });
  }

  @override
  void dispose() {
    _ffiSubscription?.cancel();
    controller.dispose();
    _webPortalService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final discoveredPeers = ref.watch(peerDiscoveryProvider);
    final activeTransfers = ref.watch(transferListProvider);

    if (_isProcessing || activeTransfers.isNotEmpty) {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D9FF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF00D9FF).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.rocket_launch_rounded,
                      color: Color(0xFF00D9FF),
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Active Live P2P Sharing',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            _selectedFileName ?? 'File Transfer in Progress',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white70,
                      ),
                      onPressed: () {
                        setState(() {
                          _isProcessing = false;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const TransferListWidget(),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00D9FF),
                  side: const BorderSide(color: Color(0xFF00D9FF)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  'Send Another File',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  setState(() {
                    _isProcessing = false;
                  });
                  _pickFile();
                },
              ),
            ],
          ),
        ),
      );
    }

    // If currently sharing a file via Web Server, show the QR Code
    if (_webShareUri != null) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_upload_outlined,
              size: 48,
              color: Colors.indigo,
            ),
            const SizedBox(height: 12),
            Text(
              'Sharing: $_sharedFileName',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Scan this QR code or open the URL to send files to this device and download shared files simultaneously.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: _webShareUri!,
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: Column(
                children: [
                  const Text(
                    'Or enter manually in any browser (same Wi-Fi):',
                    style: TextStyle(
                      color: Colors.indigo,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.language_rounded,
                        color: Colors.indigo,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SelectableText(
                          _manualShareUrl ?? _webShareUri!,
                          style: const TextStyle(
                            color: Colors.indigo,
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.copy_rounded,
                          color: Colors.indigo,
                          size: 18,
                        ),
                        tooltip: 'Copy Manual URL',
                        onPressed: () {
                          final urlToCopy = _manualShareUrl ?? _webShareUri;
                          if (urlToCopy != null) {
                            Clipboard.setData(ClipboardData(text: urlToCopy));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Manual URL copied to clipboard!',
                                ),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _stopWebShare,
              icon: const Icon(Icons.stop_rounded),
              label: const Text('Stop Sharing'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          if (!_isBluetoothAvailable) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.bluetooth_disabled_rounded,
                    color: Colors.amber.shade800,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bluetooth disabled or unavailable on this device. SwiftBeam operating in Only Wi-Fi Mode.',
                      style: TextStyle(
                        color: Colors.amber.shade900,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // File selection card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.indigo.shade100),
            ),
            child: Column(
              children: [
                if (_selectedFileName == null) ...[
                  const Text(
                    'No file selected to share',
                    style: TextStyle(
                      color: Colors.indigo,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Select File to Send'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.insert_drive_file_outlined,
                        color: Colors.indigo,
                        size: 36,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedFileName!,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(
                              'Ready to share',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.change_circle_outlined,
                          color: Colors.indigo,
                        ),
                        onPressed: _pickFile,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _startWebShare,
                    icon: const Icon(Icons.swap_vert_rounded),
                    label: const Text(
                      'Share & Receive via Simultaneous Web Portal',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Discovered Devices list
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Send to Discoverable Devices (mDNS)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          if (discoveredPeers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                children: [
                  CircularProgressIndicator(strokeWidth: 2),
                  SizedBox(height: 12),
                  Text(
                    'Looking for nearby active devices...',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: discoveredPeers.length,
              itemBuilder: (context, index) {
                final peer = discoveredPeers[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.indigo.shade100,
                      child: const Icon(
                        Icons.phone_android_rounded,
                        color: Colors.indigo,
                      ),
                    ),
                    title: Text(
                      peer.deviceName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'IP: ${peer.ip.isNotEmpty ? peer.ip : "Auto"}',
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: Colors.grey,
                    ),
                    onTap: () => _sendToMdnsPeer(peer),
                  ),
                );
              },
            ),

          // Divider + QR Camera scanner
          Container(
            height: 180,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              border: Border.all(color: Colors.grey.shade900),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              child: Stack(
                children: [
                  MobileScanner(controller: controller, onDetect: _onDetect),
                  Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.greenAccent, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Text(
                      'or Align Camera to Receiver QR Code',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
