// lib/ui/comments_sheet.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/post_service.dart';

class CommentsSheet extends StatefulWidget {
  final int postId;
  const CommentsSheet({super.key, required this.postId});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; });
    final list = await PostService.instance.getComments(postId: widget.postId);
    if (!mounted) return;
    setState(() {
      _comments = list;
      _loading = false;
    });
  }

  Future<void> _send() async {
    final txt = _controller.text.trim();
    if (txt.isEmpty) return;
    if (_isSubmitting) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to comment')));
      return;
    }

    setState(() { _isSubmitting = true; });

    try {
      final created = await PostService.instance.addComment(postId: widget.postId, text: txt);
      if (created != null) {
        setState(() {
          _comments.add(created);
          _controller.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not add comment')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() { _isSubmitting = false; });
    }
  }

  Widget _row(Map<String, dynamic> m) {
    final commenter = m['commenter'] as Map<String, dynamic>?;
    final username = commenter != null ? (commenter['username'] ?? '') as String : ((m['commenter_id'] ?? '') as String).substring(0,6);
    final pic = commenter != null ? (commenter['profile_pic'] ?? '') as String : '';
    final createdRaw = m['created_at'];
    DateTime dt;
    if (createdRaw is String) dt = DateTime.parse(createdRaw);
    else if (createdRaw is DateTime) dt = createdRaw;
    else dt = DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical:8.0, horizontal:12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: pic.isNotEmpty ? NetworkImage(pic) : null,
            child: pic.isEmpty ? const Icon(Icons.person, size: 18) : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(username, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Text(DateFormat('dd MMM, hh:mm a').format(dt), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ]),
                const SizedBox(height: 4),
                Text(m['comment'] ?? ''),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.75;
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // header
            Padding(
              padding: const EdgeInsets.symmetric(vertical:12.0, horizontal:12),
              child: Row(
                children: [
                  const Text('Comments', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
            ),

            // list
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _comments.isEmpty
                  ? const Center(child: Text('No comments yet'))
                  : ListView.builder(
                padding: const EdgeInsets.only(bottom:12),
                itemCount: _comments.length,
                itemBuilder: (_, i) => _row(_comments[i]),
              ),
            ),

            const Divider(height: 1),
            // composer
            Padding(
              padding: const EdgeInsets.fromLTRB(12,8,12,12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Add a comment...',
                        border: InputBorder.none,
                        filled: true,
                        fillColor: Color(0xFFF2F3F5),
                        contentPadding: EdgeInsets.symmetric(horizontal:12, vertical:10),
                      ),
                    ),
                  ),
                  const SizedBox(width:8),
                  SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _send,
                      child: _isSubmitting ? const SizedBox(width:16, height:16, child: CircularProgressIndicator(strokeWidth:2)) : const Text('Post'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
