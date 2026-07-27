import 'package:flutter/material.dart';

enum DevicePlatform { android, windows, macos, ios, linux }

enum ConnectionStateStatus { disconnected, connecting, connected, failed }

class DiscoveredDevice {
  final String id;
  final String name;
  final DevicePlatform platform;
  final double signalStrength; // 0.0 to 1.0
  final ConnectionStateStatus status;
  final String ipAddress;
  final int port;

  const DiscoveredDevice({
    required this.id,
    required this.name,
    required this.platform,
    required this.signalStrength,
    this.status = ConnectionStateStatus.disconnected,
    required this.ipAddress,
    this.port = 8888,
  });

  IconData get platformIcon {
    switch (platform) {
      case DevicePlatform.android:
        return Icons.android_rounded;
      case DevicePlatform.windows:
        return Icons.window_rounded;
      case DevicePlatform.macos:
        return Icons.desktop_mac_rounded;
      case DevicePlatform.ios:
        return Icons.phone_iphone_rounded;
      case DevicePlatform.linux:
        return Icons.terminal_rounded;
    }
  }

  DiscoveredDevice copyWith({
    String? id,
    String? name,
    DevicePlatform? platform,
    double? signalStrength,
    ConnectionStateStatus? status,
    String? ipAddress,
    int? port,
  }) {
    return DiscoveredDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      platform: platform ?? this.platform,
      signalStrength: signalStrength ?? this.signalStrength,
      status: status ?? this.status,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
    );
  }
}
