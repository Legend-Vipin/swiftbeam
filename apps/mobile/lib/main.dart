import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/ffi/api.dart';
import 'domain/models/transfer_history.dart';
import 'models/device_model.dart';
import 'providers/settings_provider.dart';
import 'providers/transfer_provider.dart';
import 'screens/devices_screen.dart';
import 'screens/discovery_screen.dart';
import 'screens/file_picker_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/permissions_screen.dart';
import 'screens/receiver_tablet_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/transfer_complete_screen.dart';
import 'screens/transfer_dashboard_screen.dart';
import 'theme/colors.dart';
import 'services/app_initialization_service.dart';
import 'utils/responsive.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await AppInitializationService.initialize();
  } catch (e) {
    debugPrint("Application startup initialization notice: $e");
  }
  runApp(
    const ProviderScope(
      child: SwiftBeamApp(),
    ),
  );
}

class SwiftBeamApp extends StatelessWidget {
  const SwiftBeamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SwiftBeam P2P',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: SwiftBeamColors.background,
      ),
      home: AppInitializationService.isInitialized
          ? const SwiftBeamNavigationWrapper()
          : Scaffold(
              backgroundColor: SwiftBeamColors.background,
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.amber, size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        'Initialization Notice',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppInitializationService.initializationError ??
                            'Core native components are initializing...',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry Initialization'),
                        onPressed: () async {
                          try {
                            await AppInitializationService.initialize();
                            runApp(const ProviderScope(child: SwiftBeamApp()));
                          } catch (e) {
                            debugPrint("Retry init error: $e");
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class SwiftBeamNavigationWrapper extends ConsumerStatefulWidget {
  const SwiftBeamNavigationWrapper({super.key});

  @override
  ConsumerState<SwiftBeamNavigationWrapper> createState() =>
      _SwiftBeamNavigationWrapperState();
}

class _SwiftBeamNavigationWrapperState
    extends ConsumerState<SwiftBeamNavigationWrapper> {
  int _selectedIndex = 0;

  void _navigateToScreen(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isTablet = ResponsiveLayout.isTablet(context);
    final useSideNav = isDesktop || isTablet;
    final deviceSettings = ref.watch(deviceSettingsProvider);

    final List<Widget> pages = [
      // 0: Transfer / Home Screen
      HomeScreen(
        onSendPressed: () {
          _navigateToScreen(
            FilePickerScreen(
              onSend: (selectedFiles) {
                _navigateToScreen(
                  DiscoveryScreen(
                    filesToSend: selectedFiles,
                    onStartTransfer: (qrPayload, files) {
                      String qrJson = qrPayload;
                      if (qrPayload.contains('data=')) {
                        try {
                          final uri = Uri.parse(qrPayload);
                          final base64Payload =
                              uri.queryParameters['data'] ?? '';
                          if (base64Payload.isNotEmpty) {
                            String normalized =
                                base64Payload.replaceAll(' ', '+');
                            while (normalized.length % 4 != 0) {
                              normalized += '=';
                            }
                            qrJson = utf8.decode(base64Decode(normalized));
                          }
                        } catch (_) {}
                      }

                      for (final file in files) {
                        if (file.path != null && file.path!.isNotEmpty) {
                          try {
                            final ffiStream = connectToQr(
                              qrJson: qrJson,
                              filePath: file.path!,
                            );
                            ffiStream.listen((event) {
                              ref
                                  .read(transferListProvider.notifier)
                                  .handleFfiEventJson(event,
                                      direction: TransferDirection.send);
                            }, onError: (err) {
                              debugPrint('Transfer stream error: $err');
                            });
                          } catch (e) {
                            debugPrint('connectToQr error: $e');
                          }
                        }
                      }

                      _navigateToScreen(
                        TransferDashboardScreen(
                          onComplete: () {
                            _navigateToScreen(
                              TransferCompleteScreen(
                                onSendAgain: () {
                                  Navigator.of(context)
                                      .popUntil((route) => route.isFirst);
                                },
                                onOpenFolder: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Opening SwiftBeam Received Folder...')),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
        onReceivePressed: () {
          _navigateToScreen(const ReceiverTabletScreen());
        },
        onPermissionsPressed: () {
          _navigateToScreen(
            PermissionsScreen(
              onContinue: () {
                Navigator.of(context).pop();
                _navigateToScreen(
                  DiscoveryScreen(
                    onDeviceSelected: (DiscoveredDevice dev) {},
                  ),
                );
              },
            ),
          );
        },
      ),

      // 1: History Screen
      const HistoryScreen(),

      // 2: Devices Screen
      const DevicesScreen(),

      // 3: Settings Screen
      const SettingsScreen(),
    ];

    if (useSideNav) {
      // Adaptive Desktop & Tablet Layout with NavigationRail
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (idx) =>
                  setState(() => _selectedIndex = idx),
              backgroundColor: SwiftBeamColors.surface,
              selectedIconTheme: const IconThemeData(
                  color: SwiftBeamColors.primaryCyan, size: 28),
              unselectedIconTheme:
                  const IconThemeData(color: Colors.white54, size: 24),
              selectedLabelTextStyle: const TextStyle(
                  color: SwiftBeamColors.primaryCyan,
                  fontWeight: FontWeight.bold),
              unselectedLabelTextStyle: const TextStyle(color: Colors.white54),
              extended: isDesktop,
              leading: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 20.0, horizontal: 8.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: SwiftBeamColors.primaryCyan,
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/logo.png',
                              width: 28,
                              height: 28,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.bolt_rounded,
                                color: SwiftBeamColors.background,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                        if (isDesktop) ...[
                          const SizedBox(width: 12),
                          const Text(
                            'SwiftBeam',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (isDesktop) ...[
                      const SizedBox(height: 8),
                      Text(
                        deviceSettings.deviceName,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.bolt_rounded),
                  label: Text('Transfer'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.history_rounded),
                  label: Text('History'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.devices_rounded),
                  label: Text('Devices'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_rounded),
                  label: Text('Settings'),
                ),
              ],
            ),
            const VerticalDivider(
                thickness: 1, width: 1, color: Colors.white10),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: pages,
              ),
            ),
          ],
        ),
      );
    }

    // Mobile Layout with BottomNavigationBar
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: SwiftBeamColors.surface.withValues(alpha: 0.9),
          border: Border(
            top: BorderSide(
                color: Colors.white.withValues(alpha: 0.1), width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: SwiftBeamColors.primaryCyan,
          unselectedItemColor: Colors.white54,
          onTap: (idx) => setState(() => _selectedIndex = idx),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.bolt_rounded),
              label: 'Transfer',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.devices_rounded),
              label: 'Devices',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
