// lib/pages/search.dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../services/profile_services.dart';
import 'profile.dart';
import 'common_widget.dart';
import 'package:instagram/models/search_model.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  List<UserSearchResult> _results = [];
  bool _isLoading = false;
  String _error = '';

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _error = '';
    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 350), () {
      _search(value);
    });
  }

  Future<void> _search(String query) async {
    if (!mounted) return;

    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final users = await ProfileService.instance.searchUsers(query);
      if (!mounted) return;
      setState(() {
        _results = users;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _openProfile(UserSearchResult user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfilePage(userId: user.authId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            '/home',
                (route) => false,
          ),
        ),
        title: TextField(
          controller: _controller,
          onChanged: _onQueryChanged,
          decoration: const InputDecoration(
            hintText: 'Search users',
            border: InputBorder.none,
          ),
          textInputAction: TextInputAction.search,
        ),
      ),
      body: Column(
        children: [
          if (_isLoading) const LinearProgressIndicator(),
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: _results.isEmpty && !_isLoading && _controller.text.isNotEmpty
                ? const Center(
              child: Text('No users found'),
            )
                : ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final user = _results[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: user.profilePicUrl.isNotEmpty
                        ? NetworkImage(user.profilePicUrl)
                        : null,
                    child: user.profilePicUrl.isEmpty
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(user.username),
                  subtitle: user.fullName.isNotEmpty ? Text(user.fullName) : null,
                  onTap: () => _openProfile(user),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 1), // search tab
    );
  }
}
