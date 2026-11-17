import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../domain/pace.dart';
import 'formatting.dart';
import 'session_scaffold.dart';
import 'theme.dart';
import 'widgets.dart';

/// Registro de una sesión de carrera: distancia, y ritmo al terminarla.
class RunSessionScreen extends ConsumerWidget {
  const RunSessionScreen({super.key, required this.sessionId});

  final String sessionId;

  Future<void> _editDistance(BuildContext context, int? currentM) {
    return showAppSheet<void>(
      context,
      title: 'Distancia',
      builder: (_) => _DistanceForm(sessionId: sessionId, currentM: currentM),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider(sessionId)).value;
    final distanceM = ref.watch(runDetailProvider(sessionId)).value?.distanceM;
    final durationS = session?.durationS;
    final pace = distanceM == null || durationS == null
        ? null
        : runPaceSecondsPerKm(distanceM: distanceM, durationS: durationS);

    return SessionScaffold(
      sessionId: sessionId,
      title: 'Carrera',
      summary: '',
      isEmpty: distanceM == null,
      emptyIcon: CupertinoIcons.map,
      emptyTitle: 'Sin distancia todavía',
      emptyMessage:
          'Registra la distancia al acabar de correr. '
          'El ritmo aparece cuando termines la sesión.',
      actionLabel: distanceM == null
          ? 'Registrar distancia'
          : 'Editar distancia',
      actionIcon: distanceM == null ? CupertinoIcons.add : null,
      onAction: () => _editDistance(context, distanceM),
      children: [
        const SectionHeader('Resumen'),
        CardGroup(
          children: [
            _ValueRow(
              label: 'Distancia',
              value: distanceM == null ? '—' : formatDistance(distanceM),
            ),
            _ValueRow(
              label: 'Duración',
              value: durationS == null
                  ? 'Al terminar'
                  : formatDurationMs(durationS * 1000),
              pending: durationS == null,
            ),
            _ValueRow(
              label: 'Ritmo',
              value: pace == null ? 'Al terminar' : '${formatPace(pace)} /km',
              pending: pace == null,
            ),
          ],
        ),
      ],
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.label,
    required this.value,
    this.pending = false,
  });

  final String label;
  final String value;

  /// El dato aún no existe: se muestra atenuado.
  final bool pending;

  @override
  Widget build(BuildContext context) {
    return FormRow(
      label: label,
      child: Text(
        value,
        style: textStyle(
          context,
          weight: pending ? FontWeight.w400 : FontWeight.w600,
          color: pending
              ? CupertinoColors.tertiaryLabel
              : CupertinoColors.label,
        ),
      ),
    );
  }
}

class _DistanceForm extends ConsumerStatefulWidget {
  const _DistanceForm({required this.sessionId, required this.currentM});

  final String sessionId;
  final int? currentM;

  @override
  ConsumerState<_DistanceForm> createState() => _DistanceFormState();
}

class _DistanceFormState extends ConsumerState<_DistanceForm> {
  late final _km = TextEditingController(
    text: widget.currentM == null
        ? null
        : formatNumber(widget.currentM! / 1000, decimals: 2),
  );
  String? _error;

  @override
  void dispose() {
    _km.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final km = parseNumber(_km.text);
    if (km == null || km <= 0) {
      setState(() => _error = 'Escribe la distancia en kilómetros.');
      return;
    }
    await ref
        .read(trainingRepositoryProvider)
        .setRunDistance(widget.sessionId, distanceM: (km * 1000).round());
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CardGroup(
          children: [
            FormRow(
              label: 'Distancia (km)',
              child: RowTextField(
                key: const Key('km'),
                controller: _km,
                placeholder: '0',
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
          ],
        ),
        if (_error != null) FormError(_error!),
        const SizedBox(height: 16),
        PrimaryButton(label: 'Guardar', onPressed: _save),
      ],
    );
  }
}
