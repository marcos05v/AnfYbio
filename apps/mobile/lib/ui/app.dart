import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import 'sessions_screen.dart';
import 'welcome_screen.dart';

class AnfybioApp extends StatelessWidget {
  const AnfybioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AnfYbio',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
      ),
      home: const _Root(),
    );
  }
}

/// Muestra la bienvenida hasta que existe un usuario; después, las sesiones.
class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return user.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('Error: $error'))),
      data: (user) =>
          user == null ? const WelcomeScreen() : SessionsScreen(user: user),
    );
  }
}
