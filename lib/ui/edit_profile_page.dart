// lib/pages/edit_profile_page.dart
// Edit Profile page — replace the placeholder and actually save data.
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/profile_services.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  // controllers
  final _usernameCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _dobCtrl = TextEditingController(); // yyyy-mm-dd
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();

  bool _activeStatus = true;
  bool _isPrivate = false;
  bool _isVarified = false;

  bool _loading = true;
  bool _saving = false;

  String? _profilePicUrl;
  Uint8List? _pickedImageBytes;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserRow();
  }

  Future<void> _loadCurrentUserRow() async {
    setState(() => _loading = true);
    try {
      final row = await ProfileServices.instance.getCurrentUserRow();
      if (row != null) {
        // Safe casts and defaults
        _usernameCtrl.text = (row['username'] ?? '') as String;
        _fullNameCtrl.text = (row['full_name'] ?? '') as String;
        _emailCtrl.text = (row['email_id'] ?? '') as String;
        _bioCtrl.text = (row['bio'] ?? '') as String;
        _dobCtrl.text = row['date_of_birth'] is String
            ? (row['date_of_birth'] as String)
            : (row['date_of_birth'] != null ? row['date_of_birth'].toString().split(' ').first : '');
        _cityCtrl.text = (row['city'] ?? '') as String;
        _stateCtrl.text = (row['state'] ?? '') as String;
        _countryCtrl.text = (row['country'] ?? '') as String;

        _activeStatus = (row['active_status'] ?? true) as bool;
        _isPrivate = (row['is_private'] ?? false) as bool;
        _isVarified = (row['is_varified'] ?? false) as bool;

        _profilePicUrl = (row['profile_pic'] ?? '') as String?;
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[EditProfilePage._loadCurrentUserRow] error: $e\n$st');
      }
      // show a minimal error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load profile')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _pickedImageBytes = bytes;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      String? avatarUrl = _profilePicUrl;

      if (_pickedImageBytes != null) {
        // Get current user id from service's Supabase client via ProfileServices
        final userRow = await ProfileServices.instance.getCurrentUserRow();
        final userId = userRow?['auth_id']?.toString();
        if (userId == null) throw Exception('Not authenticated');

        final uploaded = await ProfileServices.instance.uploadAvatar(
          userId: userId,
          bytes: _pickedImageBytes!,
        );
        if (uploaded != null) avatarUrl = uploaded;
      }

      // Build the map to update. Per your requirement, fill text nulls with empty strings.
      final fields = <String, dynamic>{
        'username': _usernameCtrl.text.trim().isEmpty ? '' : _usernameCtrl.text.trim(),
        'full_name': _fullNameCtrl.text.trim().isEmpty ? '' : _fullNameCtrl.text.trim(),
        'email_id': _emailCtrl.text.trim().isEmpty ? '' : _emailCtrl.text.trim(),
        'bio': _bioCtrl.text.trim().isEmpty ? '' : _bioCtrl.text.trim(),
        'date_of_birth': _dobCtrl.text.trim().isEmpty ? '' : _dobCtrl.text.trim(),
        'city': _cityCtrl.text.trim().isEmpty ? '' : _cityCtrl.text.trim(),
        'state': _stateCtrl.text.trim().isEmpty ? '' : _stateCtrl.text.trim(),
        'country': _countryCtrl.text.trim().isEmpty ? '' : _countryCtrl.text.trim(),
        'active_status': _activeStatus,
        'is_private': _isPrivate,
        'is_varified': _isVarified,
        'profile_pic': avatarUrl,
      };

      final updatedRow = await ProfileServices.instance.updateProfile(fields: fields);
      if (updatedRow == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update profile')));
      } else {
        // success — pop true so callers can refresh
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e, st) {
      if (kDebugMode) debugPrint('[EditProfilePage._save] $e\n$st');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _bioCtrl.dispose();
    _dobCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  Widget _avatarWidget() {
    final avatar = _pickedImageBytes != null
        ? Image.memory(_pickedImageBytes!, fit: BoxFit.cover)
        : (_profilePicUrl != null && _profilePicUrl!.isNotEmpty
        ? Image.network(_profilePicUrl!, fit: BoxFit.cover)
        : const Icon(Icons.person, size: 48));

    return ClipOval(
      child: SizedBox(width: 96, height: 96, child: avatar),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator())
                : const Text('Save', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      _avatarWidget(),
                      Container(
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.all(6),
                        child: const Icon(Icons.edit, color: Colors.white, size: 16),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _usernameCtrl,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Username required';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _fullNameCtrl,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email required';
                    if (!v.contains('@')) return 'Invalid email';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _bioCtrl,
                  decoration: const InputDecoration(labelText: 'Bio'),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _dobCtrl,
                  decoration: const InputDecoration(labelText: 'Date of birth (YYYY-MM-DD)'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _cityCtrl,
                  decoration: const InputDecoration(labelText: 'City'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _stateCtrl,
                  decoration: const InputDecoration(labelText: 'State'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _countryCtrl,
                  decoration: const InputDecoration(labelText: 'Country'),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Active status'),
                  value: _activeStatus,
                  onChanged: (v) => setState(() => _activeStatus = v),
                ),
                SwitchListTile(
                  title: const Text('Private account'),
                  value: _isPrivate,
                  onChanged: (v) => setState(() => _isPrivate = v),
                ),
                SwitchListTile(
                  title: const Text('Verified (admin only?)'),
                  value: _isVarified,
                  onChanged: (v) => setState(() => _isVarified = v),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Save profile'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
