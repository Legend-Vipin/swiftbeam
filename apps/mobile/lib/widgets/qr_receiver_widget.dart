import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../services/web_portal_service.dart';
import '../services/app_initialization_service.dart';
import '../core/ffi/api.dart';
import '../providers/transfer_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/permission_utils.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'transfer_widget.dart';

class QRReceiverWidget extends ConsumerStatefulWidget {
  const QRReceiverWidget({super.key});

  @override
  ConsumerState<QRReceiverWidget> createState() => _QRReceiverWidgetState();
}

class _QRReceiverWidgetState extends ConsumerState<QRReceiverWidget> {
  String? _qrUri;
  String? _manualUrl;
  bool _isGenerating = false;
  bool _isBluetoothAvailable = true;
  final WebPortalService _webPortalService = WebPortalService();
  StreamSubscription<String>? _ffiSubscription;

  @override
  void initState() {
    super.initState();
    _startReceiver();
  }

  Future<void> _startReceiver() async {
    setState(() {
      _isGenerating = true;
      _isBluetoothAvailable = true;
    });

    try {
      // 0. Ensure application initialization is complete
      if (!AppInitializationService.isInitialized) {
        await AppInitializationService.initialize();
      }

      // 0.1 Safely request permissions (bypassed on Linux/macOS/Windows/Web)
      await SafePermissionHandler.requestReceiverPermissions();

      // 0.1 Optional Bluetooth check — DO NOT fail or stop if Bluetooth is off
      if (!kIsWeb && Platform.isAndroid) {
        try {
          if (await FlutterBluePlus.adapterState.first ==
              BluetoothAdapterState.off) {
            await FlutterBluePlus.turnOn();
          }
        } catch (e) {
          debugPrint("Bluetooth non-fatal notification: $e");
          _isBluetoothAvailable = false;
        }
      }

      // 1. Get downloads directory for receiving files
      Directory? downloadsDir = await getDownloadsDirectory();
      downloadsDir ??= await getApplicationDocumentsDirectory();
      final outputDir = downloadsDir.path;

      // 2. Start Web Portal HTTP Server for no-app fallback
      final httpPort = await _webPortalService.start(outputDir: outputDir);
      final ip = await _webPortalService.getLocalIpAddress();

      final currentDeviceName = ref.read(deviceSettingsProvider).deviceName;

      // 3. Start Rust QUIC receiver via FFI
      final Stream<String> ffiStream = startQrReceiver(
        deviceName: currentDeviceName,
        outputDir: outputDir,
      );

      // Listen to the FFI stream.
      // The very first item is the QR JSON config payload.
      // Subsequent items are transfer event JSON strings.
      final completer = Completer<String>();
      _ffiSubscription = ffiStream.listen(
        (event) {
          if (!completer.isCompleted) {
            completer.complete(event);
          } else {
            // Process transfer progress events
            ref.read(transferListProvider.notifier).handleFfiEventJson(event);
          }
        },
        onError: (err) {
          if (!completer.isCompleted) {
            completer.completeError(err);
          }
        },
      );

      final ffiResult = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('QUIC server start timed out'),
      );

      final Map<String, dynamic> ffiJson = jsonDecode(ffiResult);
      final quicPort = ffiJson['port'] ?? 8080;
      final token = ffiJson['token'] ?? '';
      final pubKey = ffiJson['pub_key'] ?? '';

      // 4. Initialize mDNS peer and advertise dynamically in background
      try {
        final peerId = await initPeer(deviceName: currentDeviceName);
        await advertisePeer(
          peerId: peerId,
          deviceName: currentDeviceName,
          port: quicPort,
        );
      } catch (e) {
        debugPrint("mDNS Advertising failed to start: $e");
      }

      // 5. Formulate the QR code URL containing the Base64 QUIC metadata
      final mockMeta = jsonEncode({
        "device_id": currentDeviceName,
        "session": "RECEIVER_${DateTime.now().millisecondsSinceEpoch}",
        "ip": ip,
        "port": quicPort,
        "token": token,
        "pub_key": pubKey,
        "expires": (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600,
        "version": "1.0",
        "ble_available": _isBluetoothAvailable,
      });
      final base64Meta = base64Encode(utf8.encode(mockMeta));
      final uri = 'http://$ip:$httpPort/upload?data=$base64Meta';
      final manualUrl = 'http://$ip:$httpPort';

      setState(() {
        _qrUri = uri;
        _manualUrl = manualUrl;
        _isGenerating = false;
      });
    } catch (e, stackTrace) {
      debugPrint("QUIC FFI start error: $e\n$stackTrace");

      setState(() {
        _qrUri = null;
        _isGenerating = false;
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Diagnostic Report'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Root cause:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(e.toString()),
                  const SizedBox(height: 8),
                  const Text(
                    'Affected file:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text('lib/widgets/qr_receiver_widget.dart'),
                  const SizedBox(height: 8),
                  const Text(
                    'Affected function:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text('_startReceiver()'),
                  const SizedBox(height: 8),
                  const Text(
                    'Required fix:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Ensure RustLib is initialized and all permissions are granted.',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _ffiSubscription?.cancel();
    _webPortalService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeTransfers = ref.watch(transferListProvider);

    if (_isGenerating) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Starting Discovery & Generating QR...'),
          ],
        ),
      );
    }

    if (_qrUri == null) {
      return Center(
        child: ElevatedButton(
          onPressed: _startReceiver,
          child: const Text('Retry'),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (activeTransfers.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D97E).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF00D97E).withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.downloading_rounded,
                      color: Color(0xFF00D97E),
                      size: 28,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Receiving File Live',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'High-speed encrypted QUIC connection active',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const TransferListWidget(),
            const SizedBox(height: 16),
            const Divider(color: Colors.white12),
            const SizedBox(height: 12),
          ],
          const Text(
            'Scan to Connect',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              'Point the sender device camera at this screen to open the receiver link directly.',
              style: TextStyle(color: Colors.white70, fontSize: 12.5),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00D9FF).withValues(alpha: 0.25),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: RepaintBoundary(
              child: QrImageView(
                data: _qrUri!,
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
                embeddedImage: const AssetImage('assets/logo.png'),
                embeddedImageStyle: const QrEmbeddedImageStyle(
                  size: Size(44, 44),
                ),
                errorCorrectionLevel: QrErrorCorrectLevel.H,
              ),
            ),
          ),
          if (!_isBluetoothAvailable) ...[
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.bluetooth_disabled_rounded,
                    color: Colors.amber,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bluetooth is disabled or unavailable. Falling back strictly to Wi-Fi Direct Receiver Mode.',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF00D9FF).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                const Text(
                  'Or enter manually in any browser (same Wi-Fi):',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.language_rounded,
                      color: Color(0xFF00D9FF),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SelectableText(
                        _manualUrl ?? 'http://$_qrUri',
                        style: const TextStyle(
                          color: Color(0xFF00D9FF),
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.copy_rounded,
                        color: Color(0xFF00D9FF),
                        size: 18,
                      ),
                      tooltip: 'Copy Manual URL',
                      onPressed: () {
                        final urlToCopy = _manualUrl ?? _qrUri;
                        if (urlToCopy != null) {
                          Clipboard.setData(ClipboardData(text: urlToCopy));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Manual URL copied to clipboard!'),
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
        ],
      ),
    );
  }
}
