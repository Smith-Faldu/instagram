import 'package:flutter/material.dart';
import '../utils/responsive.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;

  const BottomNavBar({super.key, this.currentIndex = 0});

  void _goTo(BuildContext context, String routeName) {
    if (ModalRoute.of(context)?.settings.name == routeName) return;
    Navigator.pushNamedAndRemoveUntil(context, routeName, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final R = Responsive(context);

    final double iconSize = R.scaledIcon(26);
    final double paddingV = R.isPhone ? R.hp(1) : R.hp(0.7);

    return SafeArea(
      top: false,
      child: Container(
        color: Colors.white,
        padding: EdgeInsets.symmetric(vertical: paddingV),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navBtn(
                  context,
                  icon: currentIndex == 0 ? Icons.home : Icons.home_outlined,
                  index: 0,
                  route: '/home',
                  size: iconSize,
                ),
                _navBtn(
                  context,
                  icon: currentIndex == 1 ? Icons.search : Icons.search_outlined,
                  index: 1,
                  route: '/search',
                  size: iconSize,
                ),
                _navBtn(
                  context,
                  icon: currentIndex == 2 ? Icons.add_box : Icons.add_box_outlined,
                  index: 2,
                  route: '/add',
                  size: iconSize,
                ),
                _navBtn(
                  context,
                  icon: currentIndex == 3
                      ? Icons.notifications
                      : Icons.notifications_outlined,
                  index: 3,
                  route: '/notifications',
                  size: iconSize,
                ),
                _navBtn(
                  context,
                  icon: currentIndex == 4
                      ? Icons.account_circle
                      : Icons.account_circle_outlined,
                  index: 4,
                  route: '/profile',
                  size: iconSize,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navBtn(
      BuildContext context, {
        required IconData icon,
        required int index,
        required String route,
        required double size,
      }) {
    return IconButton(
      iconSize: size,
      icon: Icon(icon),
      onPressed: () => _goTo(context, route),
    );
  }
}
