import 'package:flutter/widgets.dart';

class Responsive {
  Responsive._();

  static const double desktopBreakpoint = 840;
  static const double wideDesktopBreakpoint = 1160;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktopBreakpoint;

  static bool isWideDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wideDesktopBreakpoint;
}
