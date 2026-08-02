import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/device_model.dart';

abstract class P2PService {
  bool get isBleActive;
  Future<void> startBleDiscovery();
  Future<void> stopBleDiscovery();

  Future<void> startWifiDirectHost();
  Future<void> connectToDevice(DiscoveredDevice device);

  Stream<List<DiscoveredDevice>> get discoveredDevicesStream;
  Stream<ConnectionStateStatus> get connectionStateStream;

  Future<bool> establishSecureHandshake(String remotePublicKey);
}

class SwiftBeamP2PService implements P2PService {
  final _deviceController =
      StreamController<List<DiscoveredDevice>>.broadcast();
  final _connectionController =
      StreamController<ConnectionStateStatus>.broadcast();
  final List<DiscoveredDevice> _devices = [];
  bool _isBleActive = false;
  @override
  bool get isBleActive => _isBleActive;

  @override
  Stream<List<DiscoveredDevice>> get discoveredDevicesStream =>
      _deviceController.stream;

  @override
  Stream<ConnectionStateStatus> get connectionStateStream =>
      _connectionController.stream;

  @override
  Future<void> startBleDiscovery() async {
    try {
      _isBleActive = true;
      debugPrint("Starting Bluetooth LE peer discovery...");
      _deviceController.add(_devices);
    } catch (e) {
      debugPrint(
        "Bluetooth LE unavailable ($e). Returning to Wi-Fi Direct discovery mode.",
      );
      _isBleActive = false;
      await startWifiDirectHost();
    }
  }

  @override
  Future<void> stopBleDiscovery() async {
    _isBleActive = false;
  }

  @override
  Future<void> startWifiDirectHost() async {
    debugPrint("Starting Wi-Fi Direct / Local Wi-Fi socket host...");
    _deviceController.add(_devices);
  }

  @override
  Future<void> connectToDevice(DiscoveredDevice device) async {
    _connectionController.add(ConnectionStateStatus.connecting);
    await Future.delayed(const Duration(seconds: 1));
    _connectionController.add(ConnectionStateStatus.connected);
  }

  @override
  Future<bool> establishSecureHandshake(String remotePublicKey) async {
    return true;
  }
}
