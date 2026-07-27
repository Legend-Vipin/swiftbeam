import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<String?> getDownloadsPath() async => '/tmp/downloads';
  @override
  Future<String?> getApplicationDocumentsPath() async => '/tmp/docs';
}
