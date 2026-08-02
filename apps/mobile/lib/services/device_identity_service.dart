import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceIdentityService {
  static const String _prefsCustomNameKey = 'custom_device_name';
  static String? _cachedRealDeviceName;

  /// Synchronous fallback identity using Platform OS metadata before async device_info resolves
  static String getSyncFallbackDeviceName() {
    if (_cachedRealDeviceName != null && _cachedRealDeviceName!.isNotEmpty) {
      return _cachedRealDeviceName!;
    }
    try {
      final user = Platform.environment['USER'] ??
          Platform.environment['USERNAME'] ??
          Platform.environment['LOGNAME'] ??
          '';
      final host = Platform.localHostname;
      if (user.isNotEmpty &&
          host.isNotEmpty &&
          host != 'localhost' &&
          host != '127.0.0.1') {
        return '$user ($host)';
      } else if (host.isNotEmpty &&
          host != 'localhost' &&
          host != '127.0.0.1') {
        return host;
      } else if (user.isNotEmpty) {
        return '$user Device';
      }
    } catch (e) {
      debugPrint(
        'DeviceIdentityService: Error getting sync fallback device name: $e',
      );
    }
    return 'SwiftBeam Device';
  }

  /// Detect real hardware/OS device identity based on system & user metadata
  static Future<String> getRealDeviceName() async {
    if (_cachedRealDeviceName != null && _cachedRealDeviceName!.isNotEmpty) {
      return _cachedRealDeviceName!;
    }

    String realName = '';
    final deviceInfo = DeviceInfoPlugin();

    try {
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        final browser = webInfo.browserName.name.toUpperCase();
        final platform = webInfo.platform ?? 'Web Browser';
        realName = '$browser ($platform)';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        final manufacturer = androidInfo.manufacturer;
        final model = androidInfo.model;
        final brand = androidInfo.brand;
        if (model.toLowerCase().contains(manufacturer.toLowerCase())) {
          realName = model;
        } else {
          realName = '${_capitalize(brand)} $model';
        }
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        realName = iosInfo.name.isNotEmpty
            ? iosInfo.name
            : '${iosInfo.model} (${iosInfo.systemName})';
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        final user = Platform.environment['USER'] ??
            Platform.environment['LOGNAME'] ??
            '';
        final hostName =
            linuxInfo.name.isNotEmpty ? linuxInfo.name : Platform.localHostname;
        if (user.isNotEmpty && hostName.isNotEmpty) {
          realName = '$user ($hostName)';
        } else if (hostName.isNotEmpty) {
          realName = hostName;
        } else {
          realName = 'Linux Desktop';
        }
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        final user = Platform.environment['USER'] ?? '';
        final computerName = macInfo.computerName;
        if (computerName.isNotEmpty) {
          realName = computerName;
        } else if (user.isNotEmpty) {
          realName = "$user's Mac";
        } else {
          realName = macInfo.model;
        }
      } else if (Platform.isWindows) {
        final winInfo = await deviceInfo.windowsInfo;
        final user = Platform.environment['USERNAME'] ?? '';
        final comp = winInfo.computerName;
        if (user.isNotEmpty && comp.isNotEmpty) {
          realName = '$user ($comp)';
        } else if (comp.isNotEmpty) {
          realName = comp;
        } else {
          realName = 'Windows PC';
        }
      }
    } catch (e) {
      debugPrint('DeviceIdentityService: Error detecting real device info: $e');
    }

    if (realName.trim().isEmpty ||
        realName == 'localhost' ||
        realName == '127.0.0.1') {
      final user = Platform.environment['USER'] ??
          Platform.environment['USERNAME'] ??
          '';
      final host = Platform.localHostname;
      if (host.isNotEmpty && host != 'localhost' && host != '127.0.0.1') {
        realName = user.isNotEmpty ? '$user ($host)' : host;
      } else {
        realName = user.isNotEmpty ? '$user Device' : 'SwiftBeam Device';
      }
    }

    _cachedRealDeviceName = realName.trim();
    return _cachedRealDeviceName!;
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  /// Loads saved custom device name or defaults to real device identity
  static Future<String> loadDeviceName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customName = prefs.getString(_prefsCustomNameKey);
      if (customName != null && customName.trim().isNotEmpty) {
        return customName.trim();
      }
    } catch (e) {
      debugPrint('DeviceIdentityService: Error loading saved device name: $e');
    }
    return await getRealDeviceName();
  }

  /// Save custom device name to SharedPreferences
  static Future<void> saveDeviceName(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsCustomNameKey, name.trim());
    } catch (e) {
      debugPrint('DeviceIdentityService: Error saving device name: $e');
    }
  }

  /// Reset custom device name back to detected real hardware/OS device identity
  static Future<String> resetToRealDeviceName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsCustomNameKey);
    } catch (e) {
      debugPrint('DeviceIdentityService: Error resetting device name: $e');
    }
    return await getRealDeviceName();
  }
}
