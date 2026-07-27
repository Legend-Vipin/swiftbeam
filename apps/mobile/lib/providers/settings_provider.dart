import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/device_identity_service.dart';

class DeviceSettings {
  final String deviceName;
  final String realDeviceName;
  final bool isCustomName;
  final bool autoAcceptTrusted;
  final bool isDarkTheme;
  final String downloadDirectory;

  const DeviceSettings({
    required this.deviceName,
    this.realDeviceName = '',
    this.isCustomName = false,
    this.autoAcceptTrusted = true,
    this.isDarkTheme = true,
    this.downloadDirectory = '/storage/emulated/0/Download/SwiftBeam',
  });

  DeviceSettings copyWith({
    String? deviceName,
    String? realDeviceName,
    bool? isCustomName,
    bool? autoAcceptTrusted,
    bool? isDarkTheme,
    String? downloadDirectory,
  }) {
    return DeviceSettings(
      deviceName: deviceName ?? this.deviceName,
      realDeviceName: realDeviceName ?? this.realDeviceName,
      isCustomName: isCustomName ?? this.isCustomName,
      autoAcceptTrusted: autoAcceptTrusted ?? this.autoAcceptTrusted,
      isDarkTheme: isDarkTheme ?? this.isDarkTheme,
      downloadDirectory: downloadDirectory ?? this.downloadDirectory,
    );
  }
}

class DeviceSettingsNotifier extends StateNotifier<DeviceSettings> {
  DeviceSettingsNotifier()
      : super(DeviceSettings(
          deviceName: DeviceIdentityService.getSyncFallbackDeviceName(),
          realDeviceName: DeviceIdentityService.getSyncFallbackDeviceName(),
        )) {
    _initDeviceIdentity();
  }

  Future<void> _initDeviceIdentity() async {
    final realName = await DeviceIdentityService.getRealDeviceName();
    final savedName = await DeviceIdentityService.loadDeviceName();
    final isCustom = savedName != realName;
    state = state.copyWith(
      deviceName: savedName,
      realDeviceName: realName,
      isCustomName: isCustom,
    );
  }

  Future<void> updateDeviceName(String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isNotEmpty) {
      await DeviceIdentityService.saveDeviceName(trimmed);
      state = state.copyWith(
        deviceName: trimmed,
        isCustomName: trimmed != state.realDeviceName,
      );
    }
  }

  Future<void> resetToRealName() async {
    final realName = await DeviceIdentityService.resetToRealDeviceName();
    state = state.copyWith(
      deviceName: realName,
      isCustomName: false,
    );
  }

  void toggleAutoAccept(bool value) {
    state = state.copyWith(autoAcceptTrusted: value);
  }

  void updateDownloadDirectory(String path) {
    state = state.copyWith(downloadDirectory: path);
  }
}

final deviceSettingsProvider =
    StateNotifierProvider<DeviceSettingsNotifier, DeviceSettings>((ref) {
  return DeviceSettingsNotifier();
});
