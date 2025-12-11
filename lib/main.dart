// lib/main.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/auth_gate.dart';
import 'ui/create_post_page.dart';
import 'ui/home.dart';
import 'ui/login.dart';
// replaced import for messages UI:
import 'ui/message.dart';
import 'ui/notification.dart';
import 'ui/profile.dart';
import 'ui/search_page.dart';
import 'ui/signup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://tfqouxxuqhcvfifgfcil.supabase.co',
    ),
    anonKey: const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRmcW91eHh1cWhjdmZpZmdmY2lsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ5MTI5NTQsImV4cCI6MjA4MDQ4ODk1NH0.-WA5570jRHYbw2ZX-AjM0nGx6cgsxDKNPzhubXsbEdU',
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Instagram Clone',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      home: const AuthGate(),
      routes: {
        '/login': (context) => const Login(),
        '/home': (context) => const HomePage(),
        '/search': (context) => const SearchPage(),
        '/add': (context) => const CreatePostPage(),
        '/notifications': (context) => const NotificationsPage(),
        // route now points to the new MessagesPage
        '/messages': (context) => const MessagesPage(),
        '/profile': (context) => const ProfilePage(),
        '/signup': (context) => const SignUpPage(),
      },
    );
  }
}
