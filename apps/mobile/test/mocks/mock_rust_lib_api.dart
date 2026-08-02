import 'dart:async';
import 'package:swiftbeam/core/ffi/frb_generated.dart';

class MockRustLibApi implements RustLibApi {
  @override
  Future<void> crateApiAdvertisePeer({
    required String peerId,
    required String deviceName,
    required int port,
  }) async {}

  @override
  Stream<String> crateApiConnectToQr({
    required String qrJson,
    required String filePath,
  }) =>
      const Stream.empty();

  @override
  Future<String> crateApiInitPeer({required String deviceName}) async =>
      "mock_peer";

  @override
  Stream<String> crateApiStartDiscovery() => const Stream.empty();

  @override
  Stream<String> crateApiStartQrReceiver({
    required String deviceName,
    required String outputDir,
  }) {
    return Stream.value(
      '{"port": 8080, "token": "mock_token", "pub_key": "mock_key"}',
    );
  }
}
