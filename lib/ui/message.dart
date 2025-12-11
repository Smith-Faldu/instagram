import 'package:flutter/material.dart';

class NoteCircle extends StatelessWidget {
  final String userName;
  final String userProfileUrl;

  const NoteCircle({
    super.key,
    required this.userName,
    required this.userProfileUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundImage: NetworkImage(userProfileUrl),
          ),
          const SizedBox(height: 5),
          Text(userName),
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
          NoteCircle(userName: "alex_photo", userProfileUrl: "https://images.unsplash.com/photo-1521316730702-829a8e30dfd0?w=300"),
          NoteCircle(userName: "jane_doe", userProfileUrl: "https://images.unsplash.com/photo-1500336624523-d727130c3328?w=300"),
        ],
      ),
    );
  }
}

class Chat extends StatelessWidget {
  final String username;
  final int messageCount;

  const Chat({
    super.key,
    required this.username,
    required this.messageCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: const NetworkImage(
              "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=300",
            ),
            foregroundImage: NetworkImage(
              "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=${300 + messageCount}",
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                username,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                "$messageCount new messages",
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MessageList extends StatelessWidget {
  const MessageList({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        Chat(username: "alex", messageCount: 5),
        Chat(username: "lina", messageCount: 2),
        Chat(username: "michael", messageCount: 1),
      ],
    );
  }
}

class Messages extends StatelessWidget {
  const Messages({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Messages"),
        leading: IconButton(
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
          },
          icon: const Icon(Icons.arrow_back_ios),
        ),
      ),
      body: const Column(
        children: [
          Notes(),
          Expanded(child: MessageList()),
        ],
      ),
    );
  }
}