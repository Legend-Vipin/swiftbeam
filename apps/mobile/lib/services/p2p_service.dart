import 'dart:async';
import '../models/device_model.dart';

abstract class P2PService {
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

  SwiftBeamP2PService();

  @override
  Stream<List<DiscoveredDevice>> get discoveredDevicesStream =>
      _deviceController.stream;

  @override
  Stream<ConnectionStateStatus> get connectionStateStream =>
      _connectionController.stream;

  @override
  Future<void> startBleDiscovery() async {
    _deviceController.add(_devices);
  }

  @override
  Future<void> stopBleDiscovery() async {}

  @override
  Future<void> startWifiDirectHost() async {}

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
