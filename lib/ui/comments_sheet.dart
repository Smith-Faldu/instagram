// lib/ui/comments_sheet.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/post_service.dart';
import '../utils/responsive.dart';

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
    setState(() {
      _loading = true;
    });
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please log in to comment')));
      }
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final created =
      await PostService.instance.addComment(postId: widget.postId, text: txt);
      if (created != null) {
        if (!mounted) return;
        setState(() {
          _comments.add(created);
          _controller.clear();
        });
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not add comment')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() {
        _isSubmitting = false;
      });
    }
  }

  Widget _row(Map<String, dynamic> m, Responsive R) {
    final commenter = m['commenter'] as Map<String, dynamic>?;
    final username = commenter != null
        ? (commenter['username'] ?? '') as String
        : ((m['commenter_id'] ?? '') as String).substring(0, 6);
    final pic = commenter != null ? (commenter['profile_pic'] ?? '') as String : '';
    final createdRaw = m['created_at'];
    DateTime dt;
    if (createdRaw is String) {
      dt = DateTime.tryParse(createdRaw) ?? DateTime.now();
    } else if (createdRaw is DateTime) {
      dt = createdRaw;
    } else {
      dt = DateTime.now();
    }

    final avatarRadius = R.avatarSize() / 2;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: R.hp(0.6), horizontal: R.wp(3)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: avatarRadius,
            backgroundImage: pic.isNotEmpty ? NetworkImage(pic) : null,
            child: pic.isEmpty ? Icon(Icons.person, size: avatarRadius) : null,
          ),
          SizedBox(width: R.wp(3)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(
                      username,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: R.scaledText(14),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: R.wp(2)),
                  Text(
                    DateFormat('dd MMM, hh:mm a').format(dt),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: R.scaledText(11),
                    ),
                  ),
                ]),
                SizedBox(height: R.hp(0.5)),
                Text(
                  m['comment'] ?? '',
                  style: TextStyle(fontSize: R.scaledText(14)),
                ),
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
    final R = Responsive(context);

    // Limit height to 75% of screen on phones, more on larger screens
    final maxHeight = R.isPhone ? R.hp(75) : (R.isTablet ? R.hp(80) : R.hp(85));

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maxHeight,
            maxWidth: R.isDesktop ? 800 : double.infinity,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // header
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: R.hp(1.2),
                    horizontal: R.wp(3),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Comments',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: R.scaledText(16),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // list
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _comments.isEmpty
                      ? Center(
                    child: Text(
                      'No comments yet',
                      style: TextStyle(fontSize: R.scaledText(14)),
                    ),
                  )
                      : ListView.builder(
                    padding: EdgeInsets.only(bottom: R.hp(1.5)),
                    itemCount: _comments.length,
                    itemBuilder: (_, i) => _row(_comments[i], R),
                  ),
                ),

                const Divider(height: 1),

                // composer
                Padding(
                  padding: EdgeInsets.fromLTRB(R.wp(3), R.hp(0.8), R.wp(3), R.hp(1.2)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F3F5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: R.wp(2)),
                          child: TextField(
                            controller: _controller,
                            minLines: 1,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: 'Add a comment...',
                              border: InputBorder.none,
                              hintStyle: TextStyle(fontSize: R.scaledText(14)),
                            ),
                            style: TextStyle(fontSize: R.scaledText(14)),
                          ),
                        ),
                      ),
                      SizedBox(width: R.wp(2)),
                      SizedBox(
                        height: R.buttonHeight(),
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _send,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: R.wp(3)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            minimumSize: Size(R.wp(12), R.buttonHeight()),
                          ),
                          child: _isSubmitting
                              ? SizedBox(width: R.wp(4), height: R.wp(4), child: const CircularProgressIndicator(strokeWidth: 2))
                              : Text('Post', style: TextStyle(fontSize: R.scaledText(14))),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
