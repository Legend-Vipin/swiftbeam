import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device_model.dart';
import '../services/udp_discovery_service.dart';
import 'settings_provider.dart';

final udpDiscoveryServiceProvider = Provider<UdpDiscoveryService>((ref) {
  final deviceName = ref.watch(deviceSettingsProvider).deviceName;
  return UdpDiscoveryService(
    deviceId:
        'temp_device_id', // Should be injected with actual device ID in a production setting
    deviceName: deviceName,
    platform: 'android',
    listenerPort: 8888,
  );
});

class UdpDiscoveryNotifier extends StateNotifier<List<DiscoveredDevice>> {
  final UdpDiscoveryService _service;
  StreamSubscription<List<UdpDiscoveredPeer>>? _subscription;

  UdpDiscoveryNotifier(this._service) : super([]) {
    _subscription = _service.peersStream.listen((peers) {
      state = peers.map((p) => p.toDiscoveredDevice()).toList();
    });
  }

  Future<void> start() async {
    await _service.start();
  }

  void stop() {
    _service.stop();
    state = [];
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _service.dispose();
    super.dispose();
  }
}

final udpDiscoveryProvider = StateNotifierProvider.autoDispose<
    UdpDiscoveryNotifier, List<DiscoveredDevice>>((ref) {
  final service = ref.watch(udpDiscoveryServiceProvider);
  final notifier = UdpDiscoveryNotifier(service);

  ref.onDispose(() {
    notifier.stop();
  });

  return notifier;
});
