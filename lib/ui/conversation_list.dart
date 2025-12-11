// lib/pages/conversation_list.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/message_service.dart';
import 'chat_screen.dart';

class ConversationList extends StatefulWidget {
  const ConversationList({super.key});

  @override
  State<ConversationList> createState() => _ConversationListState();
}

class _ConversationListState extends State<ConversationList> {
  final svc = MessageService();
  final SupabaseClient _client = Supabase.instance.client;
  String? _me;
  List<Map<String, dynamic>> _rows = [];
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _me = _client.auth.currentUser?.id;
    if (_me != null) _load();
    _sub = svc.subscribeConversations(_me ?? '').listen((_) {
      _load(); // simple reload for list updates
    });
  }

  Future<void> _load() async {
    if (_me == null) return;
    try {
      final rows = await svc.getConversations(_me!);
      if (!mounted) return;
      setState(() => _rows = rows);
    } catch (e) {
      debugPrint('ConversationList.load error: $e');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_me == null) return const Center(child: Text('Not logged in'));

    if (_rows.isEmpty) {
      return const Center(child: Text('No conversations'));
    }

    return ListView.builder(
      itemCount: _rows.length,
      itemBuilder: (context, i) {
        final r = _rows[i];
        final sender = r['sender_id'] as String;
        final reciver = r['reciver_id'] as String;
        final other = sender == _me ? reciver : sender;
        final lastMsg = r['message'] as String? ?? '';
        final lastAt = r['created_at'] as String? ?? '';
        final unread = (sender != _me) && ((r['seen'] as int? ?? 0) == 0);

        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text('User • ${other.substring(0,6)}'),
          subtitle: Text(lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(lastAt.split('T').first, style: const TextStyle(fontSize: 11)),
              if (unread) const SizedBox(height: 6),
              if (unread) const CircleAvatar(radius:6, backgroundColor: Colors.red),
            ],
          ),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(meId: _me!, otherId: other)));
          },
        );
      },
    );
  }
}
