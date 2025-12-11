// lib/pages/chat_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/message_service.dart';

class ChatScreen extends StatefulWidget {
  final String meId;
  final String otherId;
  const ChatScreen({super.key, required this.meId, required this.otherId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final svc = MessageService();
  final TextEditingController _ctrl = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    svc.markAsSeen(widget.meId, widget.otherId).catchError((_) {});
    _sub = svc.subscribeConversation(widget.meId, widget.otherId).listen((rows) {
      if (!mounted) return;
      setState(() => _messages = rows);
    });
  }

  Future<void> _load() async {
    try {
      final rows = await svc.fetchMessages(widget.meId, widget.otherId);
      if (!mounted) return;
      setState(() => _messages = rows);
      await svc.markAsSeen(widget.meId, widget.otherId).catchError((_) {});
    } catch (e) {
      debugPrint('chat load error: $e');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    try {
      await svc.sendMessage(widget.meId, widget.otherId, text);
      // optimistic append
      setState(() {
        _messages.add({
          'id': DateTime.now().microsecondsSinceEpoch,
          'created_at': DateTime.now().toIso8601String(),
          'sender_id': widget.meId,
          'reciver_id': widget.otherId,
          'message': text,
          'seen': 0,
        });
      });
    } catch (e) {
      debugPrint('send error: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not send message')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat • ${widget.otherId.substring(0,6)}')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final m = _messages[i];
                final isMe = (m['sender_id'] as String) == widget.meId;
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.blue : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      m['message'] ?? '',
                      style: TextStyle(color: isMe ? Colors.white : Colors.black87),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Row(
              children: [
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: const InputDecoration.collapsed(hintText: 'Message'),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                IconButton(onPressed: _send, icon: const Icon(Icons.send)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
