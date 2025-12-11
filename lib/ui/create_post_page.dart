// lib/ui/create_post_page.dart
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/post_service.dart';
import '../utils/responsive.dart';
import 'common_widget.dart'; // BottomNavBar, etc.

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _captionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final PostService _postService = PostService.instance;

  Uint8List? _mediaBytes;

  int _postFor = 1; // 1 = Public (example)
  int _postType = 1; // 1 = Post, 2 = Story, 3 = Reel
  int _postAs = 1; // 1 = Personal, 2 = Business etc.
  bool _isSaved = false; // save to highlights/saved posts

  bool _isSubmitting = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() {
        _mediaBytes = bytes;
      });
    } catch (e, st) {
      if (kDebugMode) debugPrint('pick image error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to pick image')),
        );
      }
    }
  }

  Future<void> _onSubmit() async {
    if (_isSubmitting) return;

    if (_mediaBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image first')),
      );
      return;
    }

    final caption = _captionController.text.trim();

    setState(() => _isSubmitting = true);

    // debug output so you can see what's being sent
    if (kDebugMode) {
      debugPrint(
          'Submitting: postFor=$_postFor postType=$_postType postAs=$_postAs isSaved=$_isSaved caption="$caption"');
    }

    try {
      await _postService.createPost(
        mediaBytes: _mediaBytes!,
        caption: caption,
        postFor: _postFor,
        postType: _postType,
        postAs: _postAs,
        isSaved: _isSaved,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post created successfully.')),
      );

      // Go back to home
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/home',
            (route) => false,
      );
    } catch (e, st) {
      debugPrint('createPost error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _mediaPicker(Responsive R, ThemeData theme) {
    final borderRadius = BorderRadius.circular(16.0);

    // Use AspectRatio so preview area remains consistent on wide screens
    final preview = _mediaBytes == null
        ? Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add_a_photo_outlined,
            size: R.scaledText(36),
            color: theme.colorScheme.onSurfaceVariant,
          ),
          SizedBox(height: R.hp(0.8)),
          Text(
            'Tap to select image',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: R.scaledText(14),
            ),
          ),
        ],
      ),
    )
        : ClipRRect(
      borderRadius: borderRadius,
      child: Image.memory(
        _mediaBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
    );

    // For desktop/tablet, allow a larger height
    final containerHeight = R.isDesktop
        ? R.hp(40)
        : R.isTablet
        ? R.hp(35)
        : R.hp(32);

    return GestureDetector(
      onTap: _isSubmitting ? null : _pickImage,
      child: Container(
        height: containerHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.4)),
          color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: preview,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final R = Responsive(context);

    final maxWidth = R.isDesktop ? 900.0 : (R.isTablet ? 700.0 : double.infinity);

    return Scaffold(
      appBar: AppBar(
        title: Text('Create Post', style: TextStyle(fontSize: R.scaledText(18))),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _onSubmit,
            child: _isSubmitting
                ? SizedBox(
              height: R.scaledText(18),
              width: R.scaledText(18),
              child: const CircularProgressIndicator(strokeWidth: 2),
            )
                : Text('Post', style: TextStyle(fontSize: R.scaledText(14))),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SingleChildScrollView(
              padding: R.pagePadding(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Media picker + preview
                  _mediaPicker(R, theme),
                  SizedBox(height: R.hp(2)),

                  // Caption
                  TextField(
                    controller: _captionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Caption',
                      alignLabelWithHint: true,
                      border: const OutlineInputBorder(),
                      contentPadding:
                      EdgeInsets.symmetric(horizontal: R.wp(3), vertical: R.hp(1.2)),
                    ),
                    style: TextStyle(fontSize: R.scaledText(14)),
                  ),
                  SizedBox(height: R.hp(2)),

                  // Post For (who can see)
                  DropdownButtonFormField<int>(
                    value: _postFor,
                    decoration: InputDecoration(
                      labelText: 'Post for',
                      border: const OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: R.wp(3), vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 1,
                        child: Text('Everyone (Public)'),
                      ),
                      DropdownMenuItem(
                        value: 2,
                        child: Text('Followers'),
                      ),
                      DropdownMenuItem(
                        value: 3,
                        child: Text('Close friends'),
                      ),
                    ],
                    onChanged: _isSubmitting
                        ? null
                        : (val) {
                      setState(() => _postFor = val ?? 1);
                    },
                  ),
                  SizedBox(height: R.hp(1.5)),

                  // Post type & Post as
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _postType,
                          decoration: InputDecoration(
                            labelText: 'Post type',
                            border: const OutlineInputBorder(),
                            contentPadding:
                            EdgeInsets.symmetric(horizontal: R.wp(3), vertical: 12),
                          ),
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('Post')),
                            DropdownMenuItem(value: 2, child: Text('Story')),
                            DropdownMenuItem(value: 3, child: Text('Reel')),
                          ],
                          onChanged: _isSubmitting
                              ? null
                              : (val) {
                            setState(() => _postType = val ?? 1);
                          },
                        ),
                      ),
                      SizedBox(width: R.wp(3)),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _postAs,
                          decoration: InputDecoration(
                            labelText: 'Post as',
                            border: const OutlineInputBorder(),
                            contentPadding:
                            EdgeInsets.symmetric(horizontal: R.wp(3), vertical: 12),
                          ),
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('Personal')),
                            DropdownMenuItem(value: 2, child: Text('Business')),
                            DropdownMenuItem(value: 3, child: Text('Professional')),
                          ],
                          onChanged: _isSubmitting
                              ? null
                              : (val) {
                            setState(() => _postAs = val ?? 1);
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: R.hp(1.5)),

                  // Saved toggle
                  SwitchListTile(
                    value: _isSaved,
                    onChanged: _isSubmitting
                        ? null
                        : (val) {
                      setState(() => _isSaved = val);
                    },
                    title: Text('Save to highlights', style: TextStyle(fontSize: R.scaledText(14))),
                    subtitle: Text(
                      'Toggle on to add to saved/highlights',
                      style: TextStyle(fontSize: R.scaledText(12)),
                    ),
                  ),

                  SizedBox(height: R.hp(2)),

                  // Submit button (wide)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: _isSubmitting ? const SizedBox.shrink() : const Icon(Icons.send),
                      label: _isSubmitting
                          ? SizedBox(
                        height: R.scaledText(16),
                        width: R.scaledText(16),
                        child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                          : Text('Share', style: TextStyle(fontSize: R.scaledText(15))),
                      onPressed: _isSubmitting ? null : _onSubmit,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: R.hp(1.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  SizedBox(height: R.hp(3)),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 2),
    );
  }
}
