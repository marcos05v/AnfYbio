import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/database.dart';
import '../domain/training_load.dart';
import 'formatting.dart';
import 'theme.dart';
import 'widgets.dart';

/// Carga sRPE de cada sesión terminada, ubicada en su día local.
List<LoadEntry> loadEntriesFrom(List<Session> sessions) => [
  for (final session in sessions)
    if (sessionLoad(
          durationS: session.durationS,
          sessionRpe: session.sessionRpe,
        )
        case final load?)
      LoadEntry(day: session.startedAt.toLocal(), load: load),
];

/// Carga de entrenamiento semana por semana, desde el primer registro.
///
/// La lista crece sola: cada semana nueva con sesiones añade una fila.
class LoadHistoryScreen extends ConsumerWidget {
  const LoadHistoryScreen({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsProvider(user.id)).value ?? const [];
    final entries = loadEntriesFrom(sessions);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final count = weeksOfHistory(entries, asOf: now);
    // De la más antigua a la actual; se muestran al revés.
    final loads = weeklyLoads(entries, asOf: now, weeks: count);
    final highest = loads.fold(0.0, (a, b) => a > b ? a : b);
    final secondary = textStyle(
      context,
      size: 13,
      color: CupertinoColors.secondaryLabel,
    );

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Carga por semana'),
        previousPageTitle: 'Atrás',
        border: null,
      ),
      child: SafeArea(
        child: count == 0
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.chart_bar,
                        size: 44,
                        color: resolveColor(
                          context,
                          CupertinoColors.tertiaryLabel,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Aún no hay datos',
                        style: textStyle(
                          context,
                          size: 20,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Termina una sesión para ver aquí su carga.',
                        textAlign: TextAlign.center,
                        style: secondary.copyWith(fontSize: 15),
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  screenPadding,
                  8,
                  screenPadding,
                  24,
                ),
                children: [
                  Text(
                    'Carga = minutos × esfuerzo de cada sesión.',
                    style: secondary.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 16),
                  CardGroup(
                    children: [
                      for (var weeksAgo = 0; weeksAgo < count; weeksAgo++)
                        _WeekRow(
                          weeksAgo: weeksAgo,
                          end: DateTime(
                            today.year,
                            today.month,
                            today.day - 7 * weeksAgo,
                          ),
                          load: loads[count - 1 - weeksAgo],
                          highest: highest,
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                    child: Text(
                      'Es una estimación orientativa, no un diagnóstico.',
                      style: secondary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _WeekRow extends StatelessWidget {
  const _WeekRow({
    required this.weeksAgo,
    required this.end,
    required this.load,
    required this.highest,
  });

  final int weeksAgo;

  /// Último día de la semana (ventana de 7 días).
  final DateTime end;
  final double load;
  final double highest;

  @override
  Widget build(BuildContext context) {
    final start = DateTime(end.year, end.month, end.day - 6);
    final title = switch (weeksAgo) {
      0 => 'Esta semana',
      1 => 'Semana anterior',
      _ => 'Hace $weeksAgo semanas',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textStyle(context, weight: FontWeight.w600),
                    ),
                    Text(
                      formatDayRange(start, end),
                      style: textStyle(
                        context,
                        size: 13,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                load == 0 ? 'Sin registros' : formatNumber(load, decimals: 0),
                style: load == 0
                    ? textStyle(
                        context,
                        size: 15,
                        color: CupertinoColors.tertiaryLabel,
                      )
                    : textStyle(context, size: 22, weight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Barra proporcional a la semana con más carga.
          FractionallySizedBox(
            widthFactor: highest == 0 ? 0 : (load / highest).clamp(0.0, 1.0),
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: resolveColor(
                  context,
                  weeksAgo == 0 ? accentColor : CupertinoColors.systemGrey3,
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
