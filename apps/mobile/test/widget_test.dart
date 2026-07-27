import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mock_path_provider.dart';
import 'mocks/mock_rust_lib_api.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:swiftbeam/core/ffi/frb_generated.dart';
import 'package:swiftbeam/services/app_initialization_service.dart';
import 'package:swiftbeam/main.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    PathProviderPlatform.instance = MockPathProviderPlatform();
    RustLib.initMock(api: MockRustLibApi());
    AppInitializationService.markInitializedForTest();
  });

  testWidgets('SwiftBeam app smoke test and receive flow',
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: SwiftBeamApp(),
      ),
    );

    // Verify that main title is displayed
    expect(find.text('SwiftBeam'), findsOneWidget);

    // Tap the RECEIVE button
    final receiveButton = find.text('RECEIVE');
    expect(receiveButton, findsOneWidget);
    await tester.tap(receiveButton);

    // Settle animations and navigation
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify we navigated to the Receiver Screen
    expect(find.text('Starting Discovery & Generating QR...'), findsOneWidget);
  });
}
