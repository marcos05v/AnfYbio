import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/database.dart';
import '../domain/one_rep_max.dart';
import '../domain/one_rep_max_history.dart';
import 'formatting.dart';
import 'theme.dart';
import 'widgets.dart';

/// Lista de ejercicios del usuario; cada uno abre su gráfica de progreso.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercises = ref.watch(exercisesProvider(user.id)).value ?? const [];

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Progreso de fuerza'),
        previousPageTitle: 'Atrás',
        border: null,
      ),
      child: SafeArea(
        child: exercises.isEmpty
            ? const _Empty(
                title: 'Aún no hay ejercicios',
                message:
                    'Registra una sesión de fuerza para ver aquí tu progreso.',
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  screenPadding,
                  8,
                  screenPadding,
                  24,
                ),
                children: [
                  CardGroup(
                    children: [
                      for (final exercise in exercises)
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => Navigator.of(context).push(
                            CupertinoPageRoute<void>(
                              builder: (_) =>
                                  ExerciseProgressScreen(exercise: exercise),
                            ),
                          ),
                          child: FormRow(
                            label: exercise.name,
                            child: Icon(
                              CupertinoIcons.chevron_forward,
                              size: 16,
                              color: resolveColor(
                                context,
                                CupertinoColors.tertiaryLabel,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

/// Progresión del 1RM estimado de un ejercicio, sesión por sesión.
class ExerciseProgressScreen extends ConsumerStatefulWidget {
  const ExerciseProgressScreen({super.key, required this.exercise});

  final Exercise exercise;

  @override
  ConsumerState<ExerciseProgressScreen> createState() =>
      _ExerciseProgressScreenState();
}

class _ExerciseProgressScreenState
    extends ConsumerState<ExerciseProgressScreen> {
  OneRepMaxFormula _formula = OneRepMaxFormula.epley;

  @override
  Widget build(BuildContext context) {
    final samples =
        ref.watch(setSamplesProvider(widget.exercise.id)).value ?? const [];
    final points = oneRepMaxHistory(samples, formula: _formula);
    final secondary = textStyle(
      context,
      size: 13,
      color: CupertinoColors.secondaryLabel,
    );

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.exercise.name),
        previousPageTitle: 'Atrás',
        border: null,
      ),
      child: SafeArea(
        child: points.isEmpty
            ? const _Empty(
                title: 'Aún no hay datos',
                message:
                    'El progreso se calcula con series efectivas de hasta '
                    '10 repeticiones.',
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
                    '1RM estimado',
                    style: textStyle(
                      context,
                      size: 26,
                      weight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'El peso que podrías levantar una sola vez.',
                    style: secondary.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          label: 'Mejor',
                          kg: points
                              .map((p) => p.kg)
                              .reduce((a, b) => a > b ? a : b),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Stat(label: 'Último', kg: points.last.kg),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 240,
                    padding: const EdgeInsets.fromLTRB(8, 20, 20, 10),
                    decoration: BoxDecoration(
                      color: resolveColor(context, cardColor),
                      borderRadius: BorderRadius.circular(cardRadius),
                    ),
                    child: _Chart(points: points),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoSlidingSegmentedControl<OneRepMaxFormula>(
                      groupValue: _formula,
                      padding: const EdgeInsets.all(4),
                      children: const {
                        OneRepMaxFormula.epley: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('Epley'),
                        ),
                        OneRepMaxFormula.brzycki: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('Brzycki'),
                        ),
                      },
                      onValueChanged: (formula) {
                        if (formula != null) setState(() => _formula = formula);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                    child: Text(
                      'Dos fórmulas para la misma estimación. Cuenta la mejor '
                      'serie efectiva de cada sesión, de hasta 10 repeticiones.',
                      style: secondary,
                    ),
                  ),
                  const SectionHeader('Por sesión'),
                  CardGroup(
                    children: [
                      for (final point in points.reversed)
                        FormRow(
                          label: formatShortDate(point.date),
                          child: Text(
                            '${formatNumber(point.kg)} kg',
                            style: textStyle(context, weight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.kg});

  final String label;
  final double kg;

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
          Text(
            '${formatNumber(kg)} kg',
            style: textStyle(context, size: 24, weight: FontWeight.w700),
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

/// Gráfica de línea: el eje horizontal es el tiempo real entre sesiones, no
/// su número de orden, para que un descanso largo se vea como tal.
class _Chart extends StatelessWidget {
  const _Chart({required this.points});

  final List<OneRepMaxPoint> points;

  @override
  Widget build(BuildContext context) {
    final accent = resolveColor(context, accentColor);
    final labelStyle = textStyle(
      context,
      size: 11,
      color: CupertinoColors.secondaryLabel,
    );
    final first = points.first.date;
    double dayOf(DateTime date) =>
        date.difference(first).inMinutes / Duration.minutesPerDay;

    final spots = [for (final p in points) FlSpot(dayOf(p.date), p.kg)];
    final lastDay = spots.last.x;
    final lowest = points.map((p) => p.kg).reduce((a, b) => a < b ? a : b);
    final highest = points.map((p) => p.kg).reduce((a, b) => a > b ? a : b);
    // Margen vertical para que la línea no toque los bordes; con un solo
    // punto (o todos iguales) se abre un rango mínimo.
    final margin = highest == lowest ? 5.0 : (highest - lowest) * 0.2;
    final minY = ((lowest - margin) / 5).floor() * 5.0;
    final maxY = ((highest + margin) / 5).ceil() * 5.0;

    return LineChart(
      LineChartData(
        minX: lastDay == 0 ? -1 : 0,
        maxX: lastDay == 0 ? 1 : lastDay,
        minY: minY,
        maxY: maxY,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) / 4,
          getDrawingHorizontalLine: (_) => FlLine(
            color: resolveColor(context, CupertinoColors.separator),
            strokeWidth: 0.5,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: (maxY - minY) / 4,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  formatNumber(value, decimals: 0),
                  style: labelStyle,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              // Solo se rotulan la primera y la última sesión.
              interval: lastDay == 0 ? 1 : lastDay,
              getTitlesWidget: (value, meta) {
                final date = value == 0
                    ? first
                    : value == lastDay
                    ? points.last.date
                    : null;
                if (date == null) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                  child: Text(formatShortDate(date), style: labelStyle),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) =>
                resolveColor(context, CupertinoColors.label),
            getTooltipItems: (touched) => [
              for (final spot in touched)
                LineTooltipItem(
                  '${formatNumber(spot.y)} kg\n'
                  '${formatShortDate(points[spot.spotIndex].date)}',
                  textStyle(
                    context,
                    size: 12,
                    weight: FontWeight.w600,
                    color: CupertinoColors.systemBackground,
                  ),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            color: accent,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                radius: 4,
                color: accent,
                strokeWidth: 2,
                strokeColor: resolveColor(context, cardColor),
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: accent.withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.graph_square,
              size: 44,
              color: resolveColor(context, CupertinoColors.tertiaryLabel),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: textStyle(context, size: 20, weight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textStyle(
                context,
                size: 15,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
