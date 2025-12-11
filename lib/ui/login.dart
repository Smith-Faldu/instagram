// lib/login.dart
import 'package:flutter/material.dart';
import '../services/auth_gate.dart';
import '../utils/responsive.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AuthService.instance.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final R = Responsive(context);
    final double maxWidth = R.isDesktop ? 420 : double.infinity;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: R.wp(8),
                vertical: R.hp(2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: R.hp(6)),

                  // Logo
                  Text(
                    "Instagram",
                    style: TextStyle(
                      fontSize: R.scaledText(34),
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: R.hp(4)),

                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // Email input
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      hintText: "Email",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  SizedBox(height: R.hp(1.5)),

                  // Password input
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: "Password",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  SizedBox(height: R.hp(2.5)),

                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _signIn,
                      child: _loading
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : Text(
                        "Log in",
                        style: TextStyle(fontSize: R.scaledText(14)),
                      ),
                    ),
                  ),

                  SizedBox(height: R.hp(2)),

                  Center(
                    child: Text(
                      "──────────  OR  ──────────",
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: R.scaledText(12),
                      ),
                    ),
                  ),

                  SizedBox(height: R.hp(2)),

                  // Create account
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/signup'),
                      child: Text(
                        "Create account",
                        style: TextStyle(fontSize: R.scaledText(14)),
                      ),
                    ),
                  ),

                  const Spacer(),

                  Center(
                    child: Text(
                      "Use a real email; Supabase may require confirmation.",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: R.scaledText(11),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  SizedBox(height: R.hp(1)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
