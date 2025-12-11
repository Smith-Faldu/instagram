import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;

  const BottomNavBar({super.key, this.currentIndex = 0});

  void _goTo(BuildContext context, String routeName) {
    if (ModalRoute.of(context)?.settings.name == routeName) return;
    Navigator.pushNamedAndRemoveUntil(context, routeName, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: Icon(
              currentIndex == 0 ? Icons.home : Icons.home_outlined,
            ),
            onPressed: () => _goTo(context, '/home'),
          ),
          IconButton(
            icon: Icon(
              currentIndex == 1 ? Icons.search : Icons.search_outlined,
            ),
            onPressed: () => _goTo(context, '/search'),
          ),
          IconButton(
            icon: Icon(
              currentIndex == 2 ? Icons.add_box : Icons.add_box_outlined,
            ),
            onPressed: () => _goTo(context, '/add'),
          ),
          IconButton(
            icon: Icon(
              currentIndex == 3
                  ? Icons.notifications
                  : Icons.notifications_outlined,
            ),
            onPressed: () => _goTo(context, '/notifications'),
          ),
          IconButton(
            icon: Icon(
              currentIndex == 4
                  ? Icons.account_circle
                  : Icons.account_circle_outlined,
            ),
            onPressed: () => _goTo(context, '/profile'),
          ),
        ],
      ),
    );
  }
}