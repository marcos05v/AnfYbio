import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/database.dart';
import '../data/tables/sessions.dart';
import '../domain/training_load.dart';
import 'formatting.dart';
import 'strength_session_screen.dart';

/// Pantalla principal: historial de sesiones y botón para iniciar una.
class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key, required this.user});

  final User user;

  Future<void> _startStrength(BuildContext context, WidgetRef ref) async {
    final session = await ref
        .read(trainingRepositoryProvider)
        .startSession(userId: user.id, type: SessionType.strength);
    if (context.mounted) _open(context, session);
  }

  void _open(BuildContext context, Session session) {
    if (session.type != SessionType.strength) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            StrengthSessionScreen(userId: user.id, sessionId: session.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsProvider(user.id));

    return Scaffold(
      appBar: AppBar(title: Text('Hola, ${user.displayName}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startStrength(context, ref),
        icon: const Icon(Icons.fitness_center),
        label: const Text('Sesión de fuerza'),
      ),
      body: sessions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (sessions) => sessions.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Aún no hay sesiones.\nInicia la primera con el botón de abajo.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: sessions.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) => _SessionTile(
                  session: sessions[index],
                  onTap: () => _open(context, sessions[index]),
                ),
              ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.onTap});

  final Session session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final load = sessionLoad(
      durationS: session.durationS,
      sessionRpe: session.sessionRpe,
    );
    final summary = load == null
        ? 'En curso'
        : '${session.durationS! ~/ 60} min · RPE ${session.sessionRpe}'
              ' · carga ${formatNumber(load, decimals: 0)}';

    return ListTile(
      title: Text(sessionTypeLabel(session.type)),
      subtitle: Text('${formatDateTime(session.startedAt)}\n$summary'),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
