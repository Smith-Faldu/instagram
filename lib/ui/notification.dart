// lib/NotificationsPage.dart
import 'package:flutter/material.dart';
import 'common_widget.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            '/home',
            (route) => false,
          ),
        ),
        title: const Text(
          "Notifications",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: const Notifications(),
      bottomNavigationBar: const BottomNavBar(currentIndex: 3),
    );
  }
}

enum NotificationType {
  like,
  comment,
  mention,
  follow,
}

class NotificationItem extends StatelessWidget {
  final String username;
  final String action;
  final String time;
  final String avatarUrl;
  final String? postImageUrl;
  final bool hasFollowButton;
  final NotificationType type;

  const NotificationItem({
    super.key,
    required this.username,
    required this.action,
    required this.time,
    this.avatarUrl = "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=300",
    this.postImageUrl,
    this.hasFollowButton = false,
    this.type = NotificationType.like,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: NetworkImage(avatarUrl),
              ),
              if (type != NotificationType.follow)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _getIconColor(),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      _getIcon(),
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black, fontSize: 14),
                children: [
                  TextSpan(
                    text: username,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: " $action ",
                    style: const TextStyle(color: Colors.black87),
                  ),
                  TextSpan(
                    text: time,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
          if (hasFollowButton)
            const _FollowButton()
          else if (postImageUrl != null)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                image: DecorationImage(
                  image: NetworkImage(postImageUrl!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getIcon() {
    switch (type) {
      case NotificationType.like:
        return Icons.favorite;
      case NotificationType.comment:
        return Icons.comment;
      case NotificationType.mention:
        return Icons.alternate_email;
      case NotificationType.follow:
        return Icons.person_add;
    }
  }

  Color _getIconColor() {
    switch (type) {
      case NotificationType.like:
        return Colors.red;
      case NotificationType.comment:
        return Colors.blue;
      case NotificationType.mention:
        return Colors.purple;
      case NotificationType.follow:
        return Colors.green;
    }
  }
}

class _FollowButton extends StatefulWidget {
  const _FollowButton();

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  bool isFollowing = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isFollowing ? Colors.grey[200] : Colors.blue,
          foregroundColor: isFollowing ? Colors.black : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
        onPressed: () {
          setState(() {
            isFollowing = !isFollowing;
          });
        },
        child: Text(
          isFollowing ? "Following" : "Follow",
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class Notifications extends StatelessWidget {
  const Notifications({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            "Today",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        NotificationItem(
          username: "alex_photo",
          action: "liked your photo.",
          time: "2m",
          avatarUrl: "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=300",
          postImageUrl: "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=400",
          type: NotificationType.like,
        ),
        NotificationItem(
          username: "jane_doe",
          action: "started following you.",
          time: "15m",
          avatarUrl: "https://images.unsplash.com/photo-1478720568477-152d9b164e26?w=300",
          hasFollowButton: true,
          type: NotificationType.follow,
        ),
        NotificationItem(
          username: "travel_explorer",
          action: "commented: \"Amazing shot! 🔥\"",
          time: "1h",
          avatarUrl: "https://images.unsplash.com/photo-1504198453319-5ce911bafcde?w=300",
          postImageUrl: "https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=400",
          type: NotificationType.comment,
        ),
        NotificationItem(
          username: "foodie_gram",
          action: "liked your photo.",
          time: "2h",
          avatarUrl: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=300",
          postImageUrl: "https://images.unsplash.com/photo-1521737604893-d14cc237f11d?w=400",
          type: NotificationType.like,
        ),
        NotificationItem(
          username: "style_lover",
          action: "liked your photo.",
          time: "3h",
          avatarUrl: "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=300",
          postImageUrl: "https://images.unsplash.com/photo-1500336624523-d727130c3328?w=400",
          type: NotificationType.like,
        ),
        Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            "This Week",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        NotificationItem(
          username: "photo_master",
          action: "mentioned you in a comment: \"@alex_photo check this out!\"",
          time: "2d",
          avatarUrl: "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=300",
          postImageUrl: "https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?w=400",
          type: NotificationType.mention,
        ),
        NotificationItem(
          username: "wanderlust_99",
          action: "started following you.",
          time: "3d",
          avatarUrl: "https://images.unsplash.com/photo-1504198453319-5ce911bafcde?w=300",
          hasFollowButton: true,
          type: NotificationType.follow,
        ),
        NotificationItem(
          username: "coffee_addict",
          action: "commented: \"Where is this place?\"",
          time: "4d",
          avatarUrl: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=300",
          postImageUrl: "https://images.unsplash.com/photo-1521316730702-829a8e30dfd0?w=400",
          type: NotificationType.comment,
        ),
        NotificationItem(
          username: "sunset_chaser",
          action: "liked your photo.",
          time: "5d",
          avatarUrl: "https://images.unsplash.com/photo-1478720568477-152d9b164e26?w=300",
          postImageUrl: "https://images.unsplash.com/photo-1504198453319-5ce911bafcde?w=400",
          type: NotificationType.like,
        ),
        NotificationItem(
          username: "adventure_soul",
          action: "started following you.",
          time: "6d",
          avatarUrl: "https://images.unsplash.com/photo-1504198453319-5ce911bafcde?w=300",
          hasFollowButton: true,
          type: NotificationType.follow,
        ),
      ],
    );
  }
}