// lib/pages/messages_page.dart
import 'package:flutter/material.dart';
import 'conversation_list.dart';

// re-use your NoteCircle/Notes or keep this simple placeholder
class NoteCircle extends StatelessWidget {
  final String userName;
  final String userProfileUrl;
  const NoteCircle({super.key, required this.userName, required this.userProfileUrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          CircleAvatar(radius: 32, backgroundImage: NetworkImage(userProfileUrl)),
          const SizedBox(height: 5),
          Text(userName, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class Notes extends StatelessWidget {
  const Notes({super.key});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: const [
          NoteCircle(userName: "Your Note", userProfileUrl: "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=300"),
        ],
      ),
    );
  }
}

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false),
        ),
      ),
      body: Column(
        children: const [
          Notes(),
          Expanded(child: ConversationList()),
        ],
      ),
    );
  }
}
