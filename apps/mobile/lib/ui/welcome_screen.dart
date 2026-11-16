import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';

/// Primera apertura: pide el nombre y crea el usuario local.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_name.text.trim().isEmpty) return;
    // Al crearse el usuario, currentUserProvider emite y la app cambia sola
    // a la pantalla de sesiones.
    await ref.read(userRepositoryProvider).createUser(_name.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('AnfYbio', style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 8),
              const Text('¿Cómo te llamas?'),
              const SizedBox(height: 24),
              TextField(
                controller: _name,
                autofocus: true,
                maxLength: 50,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _start(),
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: _start, child: const Text('Empezar')),
            ],
          ),
        ),
      ),
    );
  }
}
