// lib/pages/chat_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/message_service.dart';
import '../utils/responsive.dart'; // ← ensure this path is correct

class ChatScreen extends StatefulWidget {
  final String meId;
  final String otherId;

  const ChatScreen({
    super.key,
    required this.meId,
    required this.otherId,
  });

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

    svc.markAsSeen(widget.meId, widget.otherId);
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
      svc.markAsSeen(widget.meId, widget.otherId);
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

      // optimistic UI
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not send message')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final R = Responsive(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Chat • ${widget.otherId.substring(0, 6)}",
          style: TextStyle(fontSize: R.scaledText(16)),
        ),
      ),

      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: R.pagePadding(),
              child: ListView.builder(
                reverse: false,
                itemCount: _messages.length,
                itemBuilder: (context, i) {
                  final m = _messages[i];
                  final isMe = m['sender_id'] == widget.meId;

                  // bubble max width: more width allowed on large screens
                  final maxWidth = R.isDesktop
                      ? MediaQuery.of(context).size.width * 0.45
                      : R.isTablet
                      ? MediaQuery.of(context).size.width * 0.60
                      : MediaQuery.of(context).size.width * 0.75;

                  return Align(
                    alignment: isMe
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: EdgeInsets.symmetric(
                        vertical: R.hp(0.3),
                      ),
                      padding: EdgeInsets.symmetric(
                        vertical: R.hp(1),
                        horizontal: R.wp(3),
                      ),
                      constraints: BoxConstraints(
                        maxWidth: maxWidth,
                      ),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.blue : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        m['message'] ?? '',
                        style: TextStyle(
                          fontSize: R.scaledText(14),
                          color: isMe ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // INPUT BAR
          SafeArea(
            minimum: EdgeInsets.only(
              left: R.wp(3),
              right: R.wp(3),
              bottom: R.hp(1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: R.wp(3), vertical: R.hp(0.8)),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: _ctrl,
                      decoration: InputDecoration(
                        hintText: "Message",
                        border: InputBorder.none,
                        hintStyle: TextStyle(fontSize: R.scaledText(14)),
                      ),
                      style: TextStyle(fontSize: R.scaledText(14)),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                ),
                SizedBox(width: R.wp(2)),
                SizedBox(
                  height: R.buttonHeight(),
                  width: R.buttonHeight(),
                  child: ElevatedButton(
                    onPressed: _send,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: const CircleBorder(),
                    ),
                    child: Icon(Icons.send, size: R.scaledText(18)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
