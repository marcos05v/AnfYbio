import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/database.dart';
import '../data/tables/sessions.dart';
import '../domain/training_load.dart';
import 'apnea_session_screen.dart';
import 'formatting.dart';
import 'load_history_screen.dart';
import 'progress_screen.dart';
import 'run_session_screen.dart';
import 'settings_screen.dart';
import 'strength_session_screen.dart';
import 'swim_session_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// Pantalla principal: resumen de la semana, historial y botón para iniciar.
class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key, required this.user});

  final User user;

  /// Pregunta qué tipo de sesión iniciar, la crea y abre su pantalla.
  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final type = await showAppSheet<SessionType>(
      context,
      title: '¿Qué vas a entrenar?',
      builder: (context) => CardGroup(
        children: [
          for (final type in SessionType.values)
            CupertinoButton(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              onPressed: () => Navigator.of(context).pop(type),
              child: Row(
                children: [
                  SessionTypeIcon(type, size: 44),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sessionTypeLabel(type),
                          style: textStyle(context, weight: FontWeight.w600),
                        ),
                        Text(
                          sessionTypeDescription(type),
                          style: textStyle(
                            context,
                            size: 13,
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    CupertinoIcons.chevron_forward,
                    size: 16,
                    color: resolveColor(context, CupertinoColors.tertiaryLabel),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    if (type == null || !context.mounted) return;

    final repository = ref.read(trainingRepositoryProvider);
    final Session session;
    if (type == SessionType.swim) {
      final poolLengthM = await _askPoolLength(context);
      if (poolLengthM == null) return;
      session = await repository.startSwimSession(
        userId: user.id,
        poolLengthM: poolLengthM,
      );
    } else {
      session = await repository.startSession(userId: user.id, type: type);
    }
    if (context.mounted) _open(context, session);
  }

  /// La natación necesita el tamaño de la alberca antes de empezar.
  Future<int?> _askPoolLength(BuildContext context) async {
    const other = -1;
    final choice = await showCupertinoModalPopup<int>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Tamaño de la alberca'),
        actions: [
          for (final meters in const [25, 50])
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop(meters),
              child: Text('$meters m'),
            ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(other),
            child: const Text('Otra medida…'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ),
    );
    if (choice != other || !context.mounted) return choice;

    final controller = TextEditingController();
    final meters = await showCupertinoDialog<int>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Tamaño de la alberca'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            key: const Key('poolLength'),
            controller: controller,
            placeholder: 'Metros',
            autofocus: true,
            keyboardType: TextInputType.number,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value != null && value > 0) Navigator.of(context).pop(value);
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return meters;
  }

  void _open(BuildContext context, Session session) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => switch (session.type) {
          SessionType.strength => StrengthSessionScreen(
            userId: user.id,
            sessionId: session.id,
          ),
          SessionType.swim => SwimSessionScreen(sessionId: session.id),
          SessionType.run => RunSessionScreen(sessionId: session.id),
          SessionType.apnea => ApneaSessionScreen(sessionId: session.id),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsProvider(user.id)).value ?? const [];

    return CupertinoPageScaffold(
      child: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                CupertinoSliverNavigationBar(
                  largeTitle: const Text('Entrenamientos'),
                  border: null,
                  trailing: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (_) => SettingsScreen(user: user),
                      ),
                    ),
                    child: const Icon(
                      CupertinoIcons.gear_alt,
                      semanticLabel: 'Ajustes',
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: screenPadding,
                  ),
                  sliver: SliverList.list(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          'Hola, ${user.displayName}',
                          style: textStyle(
                            context,
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                      ),
                      _WeekSummary(user: user, sessions: sessions),
                      const SectionHeader('Historial'),
                      if (sessions.isEmpty)
                        const _EmptyHistory()
                      else
                        CardGroup(
                          children: [
                            for (final session in sessions)
                              _SessionRow(
                                session: session,
                                onTap: () => _open(context, session),
                              ),
                          ],
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
          BottomActionBar(
            child: PrimaryButton(
              label: 'Iniciar sesión',
              icon: CupertinoIcons.add,
              onPressed: () => _start(context, ref),
            ),
          ),
        ],
      ),
    );
  }
}

/// Resumen de los últimos 7 días: sesiones, tiempo y carga de entrenamiento
/// comparada con las tres semanas anteriores.
class _WeekSummary extends StatelessWidget {
  const _WeekSummary({required this.user, required this.sessions});

  final User user;
  final List<Session> sessions;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day - 6);
    final thisWeek = [
      for (final session in sessions)
        if (!session.startedAt.toLocal().isBefore(weekStart)) session,
    ];
    final minutes =
        thisWeek.fold(0, (sum, s) => sum + (s.durationS ?? 0)) ~/ 60;

    final entries = loadEntriesFrom(sessions);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _Stat(
                value: '${thisWeek.length}',
                label: 'Sesiones · 7 días',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Stat(
                value: _formatMinutes(minutes),
                label: 'Tiempo · 7 días',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _LoadCard(
          summary: summarizeLoad(entries, asOf: now),
          onShowWeeks: () => Navigator.of(context).push(
            CupertinoPageRoute<void>(
              builder: (_) => LoadHistoryScreen(user: user),
            ),
          ),
        ),
        const SizedBox(height: 12),
        CardGroup(
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => ProgressScreen(user: user),
                ),
              ),
              child: FormRow(
                label: 'Progreso de fuerza',
                child: Icon(
                  CupertinoIcons.chevron_forward,
                  size: 16,
                  color: resolveColor(context, CupertinoColors.tertiaryLabel),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _formatMinutes(int minutes) => minutes < 60
      ? '$minutes min'
      : minutes % 60 == 0
      ? '${minutes ~/ 60} h'
      : '${minutes ~/ 60} h ${minutes % 60} min';
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: resolveColor(context, cardColor),
        borderRadius: BorderRadius.circular(cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: textStyle(context, size: 28, weight: FontWeight.w700),
            ),
          ),
          Text(
            label,
            style: textStyle(
              context,
              size: 13,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ],
      ),
    );
  }
}

/// Carga de entrenamiento de esta semana y acceso al historial por semana.
class _LoadCard extends StatelessWidget {
  const _LoadCard({required this.summary, required this.onShowWeeks});

  final LoadSummary summary;
  final VoidCallback onShowWeeks;

  @override
  Widget build(BuildContext context) {
    final ratio = summary.ratio;
    // Solo hay comparación con 4 semanas de historial; antes no se muestra.
    final comparison = switch (ratio) {
      null => null,
      _ when (ratio - 1).abs() < 0.05 => 'Igual que tu promedio',
      > 1 => '${((ratio - 1) * 100).round()} % más que tu promedio',
      _ => '${((1 - ratio) * 100).round()} % menos que tu promedio',
    };
    final secondary = textStyle(
      context,
      size: 13,
      color: CupertinoColors.secondaryLabel,
    );

    return Container(
      decoration: BoxDecoration(
        color: resolveColor(context, cardColor),
        borderRadius: BorderRadius.circular(cardRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Carga de esta semana',
                        style: textStyle(context, weight: FontWeight.w600),
                      ),
                      Text(
                        comparison ?? 'Minutos × esfuerzo',
                        style: secondary,
                      ),
                    ],
                  ),
                ),
                Text(
                  formatNumber(summary.acute, decimals: 0),
                  key: const Key('weekLoad'),
                  style: textStyle(context, size: 28, weight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Container(
            height: 0.5,
            margin: const EdgeInsets.only(left: 16),
            color: resolveColor(context, CupertinoColors.separator),
          ),
          CupertinoButton(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            onPressed: onShowWeeks,
            child: Row(
              children: [
                const Expanded(child: Text('Ver por semana')),
                Icon(
                  CupertinoIcons.chevron_forward,
                  size: 16,
                  color: resolveColor(context, CupertinoColors.tertiaryLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: resolveColor(context, cardColor),
        borderRadius: BorderRadius.circular(cardRadius),
      ),
      child: Text(
        'Aún no hay sesiones.\nInicia la primera con el botón de abajo.',
        textAlign: TextAlign.center,
        style: textStyle(context, color: CupertinoColors.secondaryLabel),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.onTap});

  final Session session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final load = sessionLoad(
      durationS: session.durationS,
      sessionRpe: session.sessionRpe,
    );
    return CupertinoButton(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      onPressed: onTap,
      child: Row(
        children: [
          SessionTypeIcon(session.type),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sessionTypeLabel(session.type),
                  style: textStyle(context, weight: FontWeight.w600),
                ),
                Text(
                  formatDateTime(session.startedAt),
                  style: textStyle(
                    context,
                    size: 13,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
                if (load != null)
                  Text(
                    '${session.durationS! ~/ 60} min · RPE ${session.sessionRpe}'
                    ' · carga ${formatNumber(load, decimals: 0)}',
                    style: textStyle(
                      context,
                      size: 13,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
              ],
            ),
          ),
          if (load == null) const StatusDot('En curso'),
          const SizedBox(width: 6),
          Icon(
            CupertinoIcons.chevron_forward,
            size: 16,
            color: resolveColor(context, CupertinoColors.tertiaryLabel),
          ),
        ],
      ),
    );
  }
}
