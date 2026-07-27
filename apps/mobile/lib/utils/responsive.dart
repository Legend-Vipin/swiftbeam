import 'package:flutter/material.dart';

enum DeviceFormFactor { mobile, tablet, desktop }

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1024;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1024;

  static DeviceFormFactor getFormFactor(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1024) return DeviceFormFactor.desktop;
    if (width >= 600) return DeviceFormFactor.tablet;
    return DeviceFormFactor.mobile;
  }

  @override
  Widget build(BuildContext context) {
    final formFactor = getFormFactor(context);
    switch (formFactor) {
      case DeviceFormFactor.desktop:
        return desktop ?? tablet ?? mobile;
      case DeviceFormFactor.tablet:
        return tablet ?? mobile;
      case DeviceFormFactor.mobile:
        return mobile;
    }
  }
}
