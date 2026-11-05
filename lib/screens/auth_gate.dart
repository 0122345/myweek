import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../repositories/course_repository.dart';
import '../state/week_state.dart';
import 'login_screen.dart';
import 'week_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }
        // One brain per user; the key forces a fresh one.
        return ChangeNotifierProvider<WeekState>(
          key: ValueKey(user.uid),
          create: (_) => WeekState(CourseRepository(user.uid)),
          child: const WeekScreen(),
        );
      },
    );
  }
}
