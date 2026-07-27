import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class SafePermissionHandler {
  /// Safely requests permissions suitable for the current operating platform.
  /// Desktop (Linux, Windows, macOS) and Web do not use permission_handler method channels.
  static Future<void> requestReceiverPermissions() async {
    if (kIsWeb || Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      // Desktop & Web platforms handle operating system level permissions outside of permission_handler
      return;
    }

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final permissionsToRequest = <Permission>[];

        if (Platform.isAndroid) {
          permissionsToRequest.addAll([
            Permission.bluetoothScan,
            Permission.bluetoothConnect,
            Permission.bluetoothAdvertise,
            Permission.nearbyWifiDevices,
            Permission.location,
            Permission.camera,
            Permission.storage,
            Permission.manageExternalStorage,
          ]);
        } else if (Platform.isIOS) {
          permissionsToRequest.addAll([
            Permission.bluetooth,
            Permission.location,
            Permission.camera,
            Permission.photos,
          ]);
        }

        await permissionsToRequest.request();
      }
    } catch (e) {
      debugPrint("SafePermissionHandler request error: $e");
    }
  }

  /// Check individual permission status safely per platform.
  static Future<bool> isGranted(Permission permission) async {
    if (kIsWeb || Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      return true;
    }
    try {
      return await permission.isGranted;
    } catch (e) {
      debugPrint("SafePermissionHandler isGranted error: $e");
      return true;
    }
  }
}
