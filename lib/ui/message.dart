// lib/pages/messages_page.dart
import 'package:flutter/material.dart';
import 'conversation_list.dart';
import '../utils/responsive.dart';

class NoteCircle extends StatelessWidget {
  final String userName;
  final String? userProfileUrl;
  const NoteCircle({super.key, required this.userName, this.userProfileUrl});

  @override
  Widget build(BuildContext context) {
    final R = Responsive(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: R.wp(2), vertical: R.hp(0.8)),
      child: Column(
        children: [
          CircleAvatar(
            radius: R.avatarSize() / 2,
            backgroundImage: (userProfileUrl != null && userProfileUrl!.isNotEmpty)
                ? NetworkImage(userProfileUrl!)
                : null,
            child: (userProfileUrl == null || userProfileUrl!.isEmpty) ? Icon(Icons.person, size: R.scaledText(18)) : null,
          ),
          SizedBox(height: R.hp(0.5)),
          SizedBox(
            width: R.wp(20),
            child: Text(userName, style: TextStyle(fontSize: R.scaledText(12)), overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

class Notes extends StatelessWidget {
  const Notes({super.key});
  @override
  Widget build(BuildContext context) {
    final R = Responsive(context);
    return SizedBox(
      height: R.hp(13),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: R.wp(2)),
        children: const [
          NoteCircle(userName: "Your Note", userProfileUrl: "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=300"),
          // add more note circles or make this dynamic later
        ],
      ),
    );
  }
}

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  void _goBack(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final R = Responsive(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Messages', style: TextStyle(fontSize: R.scaledText(18), fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: R.scaledText(18)),
          onPressed: () => _goBack(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.create, size: R.scaledText(20)),
            onPressed: () {
              // TODO: open compose screen — for now just show a snackbar
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compose not implemented')));
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: R.wp(2)),
          child: Column(
            children: const [
              Notes(),
              SizedBox(height: 8),
              Expanded(child: ConversationList()),
            ],
          ),
        ),
      ),
      // optional floating action for quick compose on mobile
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compose not implemented')));
        },
        child: Icon(Icons.chat, size: R.scaledText(20)),
      ),
    );
  }
}
