import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import '../core/ffi/frb_generated.dart';
import '../utils/permission_utils.dart';

class AppInitializationService {
  static bool _initialized = false;
  static String? _initializationError;

  static bool get isInitialized => _initialized;
  static String? get initializationError => _initializationError;

  @visibleForTesting
  static void markInitializedForTest() {
    _initialized = true;
    _initializationError = null;
  }

  /// Performs single-point, guaranteed initialization of Flutter, Rust FFI, and system permissions.
  /// Handles both release bundle locations and development/debug cargo target paths.
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // 1. Ensure Flutter bindings are ready
      WidgetsFlutterBinding.ensureInitialized();

      // 2. Initialize Rust FFI Library (flutter_rust_bridge) with smart path fallback
      try {
        await RustLib.init();
      } catch (e) {
        if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
          debugPrint(
            "Default RustLib.init failed ($e). Attempting desktop candidate library search...",
          );
          final externalLib = _findDesktopExternalLibrary();
          if (externalLib != null) {
            await RustLib.init(externalLibrary: externalLib);
          } else {
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      // 3. Request platform permissions safely (guarded against desktop plugin errors)
      await SafePermissionHandler.requestReceiverPermissions();

      _initialized = true;
      _initializationError = null;
      debugPrint(
        "AppInitializationService: RustLib & platform services initialized successfully.",
      );
    } catch (e, stackTrace) {
      _initialized = false;
      _initializationError = e.toString();
      debugPrint(
        "AppInitializationService fatal initialization error: $e\n$stackTrace",
      );
      rethrow;
    }
  }

  /// Locate desktop dynamic library across release bundle and development target paths
  static ExternalLibrary? _findDesktopExternalLibrary() {
    String libName;
    if (Platform.isLinux) {
      libName = 'libswiftbeam_ffi.so';
    } else if (Platform.isWindows) {
      libName = 'swiftbeam_ffi.dll';
    } else if (Platform.isMacOS) {
      libName = 'libswiftbeam_ffi.dylib';
    } else {
      return null;
    }

    final candidatePaths = [
      // 1. Current executable directory (Release bundle)
      File('${File(Platform.resolvedExecutable).parent.path}/lib/$libName'),
      File('${File(Platform.resolvedExecutable).parent.path}/$libName'),
      // 2. Cargo workspace target release path
      File('../../core/target/release/$libName'),
      File('../../core/swiftbeam-ffi/target/release/$libName'),
      // 3. Cargo workspace target debug path (Dev / debug mode)
      File('../../core/target/debug/$libName'),
      File('../../core/swiftbeam-ffi/target/debug/$libName'),
      // 4. Absolute cargo workspace target release path
      File('${Directory.current.path}/../../core/target/release/$libName'),
      File(
        '${Directory.current.path}/../../core/swiftbeam-ffi/target/release/$libName',
      ),
      // 5. Absolute cargo workspace target debug path
      File('${Directory.current.path}/../../core/target/debug/$libName'),
      File(
        '${Directory.current.path}/../../core/swiftbeam-ffi/target/debug/$libName',
      ),
    ];

    for (final file in candidatePaths) {
      if (file.existsSync()) {
        debugPrint(
          "AppInitializationService: Found native library at ${file.path}",
        );
        return ExternalLibrary.open(file.path);
      }
    }
    return null;
  }
}
