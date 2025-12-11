// lib/ui/create_post_page.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/post_service.dart';
import 'common_widget.dart'; // BottomNavBar, etc.

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _captionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final PostService _postService = PostService();

  Uint8List? _mediaBytes;

  int _postFor = 1; // 1 = Public (example)
  int _postType = 1; // 1 = Image/Post, 2 = Story, 3 = Reel, etc.
  int _postAs = 1; // 1 = Personal, 2 = Business etc.
  bool _isSaved = false; // save to highlights/saved posts

  bool _isSubmitting = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();

    setState(() {
      _mediaBytes = bytes;
    });
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
    debugPrint(
        'Submitting: postFor=$_postFor postType=$_postType postAs=$_postAs isSaved=$_isSaved caption="$caption"');

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
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _onSubmit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Post'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Media picker + preview
              GestureDetector(
                onTap: _isSubmitting ? null : _pickImage,
                child: Container(
                  height: 250,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.4),
                    ),
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                  ),
                  child: _mediaBytes == null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_a_photo_outlined,
                                size: 40,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap to select image',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(
                            _mediaBytes!,
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Caption
              TextField(
                controller: _captionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Caption',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Post For (who can see)
              DropdownButtonFormField<int>(
                value: _postFor,
                decoration: const InputDecoration(
                  labelText: 'Post for',
                  border: OutlineInputBorder(),
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
                        setState(() {
                          _postFor = val ?? 1;
                        });
                      },
              ),
              const SizedBox(height: 12),

              // Post type & Post as
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _postType,
                      decoration: const InputDecoration(
                        labelText: 'Post type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 1,
                          child: Text('Post'),
                        ),
                        DropdownMenuItem(
                          value: 2,
                          child: Text('Story'),
                        ),
                        DropdownMenuItem(
                          value: 3,
                          child: Text('Reel'),
                        ),
                      ],
                      onChanged: _isSubmitting
                          ? null
                          : (val) {
                              setState(() {
                                _postType = val ?? 1;
                              });
                            },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _postAs,
                      decoration: const InputDecoration(
                        labelText: 'Post as',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 1,
                          child: Text('Personal'),
                        ),
                        DropdownMenuItem(
                          value: 2,
                          child: Text('Business'),
                        ),
                        DropdownMenuItem(
                          value: 3,
                          child: Text('Professional'),
                        ),
                      ],
                      onChanged: _isSubmitting
                          ? null
                          : (val) {
                              setState(() {
                                _postAs = val ?? 1;
                              });
                            },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Saved toggle
              SwitchListTile(
                value: _isSaved,
                onChanged: _isSubmitting
                    ? null
                    : (val) {
                        setState(() {
                          _isSaved = val;
                        });
                      },
                title: const Text('You Want to save it??'),
                subtitle: const Text('Toggle on to add to saved/highlights'),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 2),
    );
  }
}
