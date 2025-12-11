import 'package:flutter/widgets.dart';

class Responsive {
  final BuildContext context;
  final Size size;
  final double width;
  final double height;
  final double textScale;

  Responsive(this.context)
      : size = MediaQuery.of(context).size,
        width = MediaQuery.of(context).size.width,
        height = MediaQuery.of(context).size.height,
        textScale = MediaQuery.of(context).textScaleFactor;

  // Breakpoints (tweak to taste)
  bool get isPhone => width < 600;
  bool get isTablet => width >= 600 && width < 1024;
  bool get isDesktop => width >= 1024;

  // Example helpers
  double wp(double fraction) => width * fraction; // width percentage: 0.1 => 10%
  double hp(double fraction) => height * fraction;
  double scaledText(double base) => base * textScale * (isTablet ? 1.15 : (isDesktop ? 1.25 : 1.0));

  // Avatar sizes
  double avatarSize() {
    if (isPhone) return 48;
    if (isTablet) return 72;
    return 96;
  }
  double scaledIcon(double base) => base * textScale * (isTablet ? 1.15 : (isDesktop ? 1.25 : 1.0));

  // Button sizes
  double buttonHeight() {
    if (isPhone) return 36;
    if (isTablet) return 44;
    return 52;
  }

  EdgeInsetsGeometry pagePadding() {
    if (isPhone) return const EdgeInsets.symmetric(horizontal: 12, vertical: 12);
    if (isTablet) return const EdgeInsets.symmetric(horizontal: 20, vertical: 16);
    return const EdgeInsets.symmetric(horizontal: 32, vertical: 20);
  }
}
