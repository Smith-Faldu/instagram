// lib/signup.dart
import 'package:flutter/material.dart';

import '../services/auth_gate.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  DateTime? _selectedDob;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _selectedDob ?? DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobController.text = _formatDate(picked);
      });
    }
  }

  String _formatDate(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  Future<void> _submit() async {
    // basic guard
    if (_submitting) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || _selectedDob == null) {
      setState(() {
        _error = _selectedDob == null ? 'Please pick your date of birth.' : null;
        _submitting = false;
      });
      return;
    }

    try {
      // NOTE: use backend field names expected by your DB / RPC
      // I changed 'dob' -> 'date_of_birth' because your DB uses date_of_birth
      await AuthService.instance.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {
          'username': _usernameController.text.trim(),
          'full_name': _fullNameController.text.trim(),
          'date_of_birth': _formatDate(_selectedDob!), // <- important
        },
      );

      if (!mounted) return;
      // show success and navigate back to login — your original popped as well
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created. Check your email to confirm.'),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      // try to present useful error text (AuthService likely throws readable messages)
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = _submitting;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign up'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const Text(
                'Create your account',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              TextFormField(
                controller: _usernameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a username' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter email';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fullNameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter full name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dobController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Date of birth',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: disabled ? null : _pickDob,
                  ),
                ),
                onTap: disabled ? null : _pickDob,
                validator: (_) => _selectedDob == null ? 'Pick your date of birth' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: disabled ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Create account'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Already have an account? Log in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
