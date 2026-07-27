import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/device_model.dart';

class UdpDiscoveredPeer {
  final String id;
  final String name;
  final String platform;
  final String ip;
  final int port;
  final int lastSeen;

  const UdpDiscoveredPeer({
    required this.id,
    required this.name,
    required this.platform,
    required this.ip,
    required this.port,
    required this.lastSeen,
  });

  DiscoveredDevice toDiscoveredDevice() {
    DevicePlatform devicePlatform;
    switch (platform.toLowerCase()) {
      case 'android':
        devicePlatform = DevicePlatform.android;
        break;
      case 'windows':
        devicePlatform = DevicePlatform.windows;
        break;
      case 'macos':
        devicePlatform = DevicePlatform.macos;
        break;
      case 'ios':
        devicePlatform = DevicePlatform.ios;
        break;
      case 'linux':
        devicePlatform = DevicePlatform.linux;
        break;
      default:
        devicePlatform = DevicePlatform.android; // fallback
    }

    return DiscoveredDevice(
      id: id,
      name: name,
      platform: devicePlatform,
      signalStrength: 1.0,
      ipAddress: ip,
      port: port,
    );
  }
}

class UdpDiscoveryService {
  static const int _port = 53317;
  static const Duration _broadcastInterval = Duration(seconds: 2);
  static const Duration _staleTimeout = Duration(seconds: 10);

  final String deviceId;
  final String deviceName;
  final String platform;
  final int listenerPort;

  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  Timer? _cleanupTimer;

  final Map<String, UdpDiscoveredPeer> _peers = {};
  final StreamController<List<UdpDiscoveredPeer>> _peersController =
      StreamController<List<UdpDiscoveredPeer>>.broadcast();

  Stream<List<UdpDiscoveredPeer>> get peersStream => _peersController.stream;
  bool _isRunning = false;

  UdpDiscoveryService({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.listenerPort,
  });

  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;

    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _port);
      _socket?.broadcastEnabled = true;

      _socket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          _handleMessage();
        }
      }, onError: (Object e) {
        // Handle socket errors gracefully
      });

      _broadcastTimer =
          Timer.periodic(_broadcastInterval, (_) => _broadcastPresence());
      _cleanupTimer = Timer.periodic(
          const Duration(seconds: 2), (_) => _cleanupStalePeers());

      _broadcastPresence();
    } catch (e) {
      _isRunning = false;
      // Handle bind failure gracefully
    }
  }

  void _handleMessage() {
    try {
      final datagram = _socket?.receive();
      if (datagram == null) return;

      final message = utf8.decode(datagram.data);
      final data = jsonDecode(message) as Map<String, dynamic>;

      final id = data['device_id'] as String?;
      final name = data['device_name'] as String?;
      final plat = data['platform'] as String?;
      final port = data['port'] as int?;

      if (id == null ||
          name == null ||
          plat == null ||
          port == null ||
          id == deviceId) {
        return;
      }

      final peer = UdpDiscoveredPeer(
        id: id,
        name: name,
        platform: plat,
        ip: datagram.address.address,
        port: port,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      );

      _peers[id] = peer;
      _emitPeers();
    } catch (e) {
      // Ignore invalid packets
    }
  }

  Future<void> _broadcastPresence() async {
    if (_socket == null) return;

    final payload = jsonEncode({
      'device_id': deviceId,
      'device_name': deviceName,
      'platform': platform,
      'port': listenerPort,
      'version': '1.0',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    final data = utf8.encode(payload);

    try {
      // Broadcast to 255.255.255.255
      _socket?.send(data, InternetAddress('255.255.255.255'), _port);

      // Broadcast to all interface subnets
      final interfaces = await NetworkInterface.list(
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );

      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          // Simple heuristic for /24 subnet broadcast
          final parts = addr.address.split('.');
          if (parts.length == 4) {
            parts[3] = '255';
            final broadcastAddress = parts.join('.');
            try {
              _socket?.send(data, InternetAddress(broadcastAddress), _port);
            } catch (e) {
              // Ignore invalid address errors
            }
          }
        }
      }
    } catch (e) {
      // Handle send errors gracefully
    }
  }

  void _cleanupStalePeers() {
    final now = DateTime.now().millisecondsSinceEpoch;
    bool changed = false;

    _peers.removeWhere((id, peer) {
      final isStale = (now - peer.lastSeen) > _staleTimeout.inMilliseconds;
      if (isStale) changed = true;
      return isStale;
    });

    if (changed) {
      _emitPeers();
    }
  }

  void _emitPeers() {
    if (!_peersController.isClosed) {
      _peersController.add(_peers.values.toList());
    }
  }

  void stop() {
    _isRunning = false;
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _socket?.close();
    _socket = null;
    _peers.clear();
    _emitPeers();
  }

  void dispose() {
    stop();
    _peersController.close();
  }
}
