import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/database.dart';
import '../data/tables/apnea_attempts.dart';
import 'formatting.dart';
import 'session_scaffold.dart';
import 'widgets.dart';

const apneaSafetyMessage =
    'Nunca practiques apnea solo en el agua. '
    'Entrena siempre con alguien que te vigile.';

/// Registro de una sesión de apnea: intentos de estática y dinámica.
///
/// El aviso de seguridad queda fijo en la pantalla y se repite en el
/// formulario: debe verse siempre que se registra un intento.
class ApneaSessionScreen extends ConsumerStatefulWidget {
  const ApneaSessionScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<ApneaSessionScreen> createState() => _ApneaSessionScreenState();
}

class _ApneaSessionScreenState extends ConsumerState<ApneaSessionScreen> {
  ApneaKind _lastKind = ApneaKind.static;

  Future<void> _addAttempt() async {
    final kind = await showAppSheet<ApneaKind>(
      context,
      title: 'Nuevo intento',
      builder: (_) =>
          _AddAttemptForm(sessionId: widget.sessionId, initialKind: _lastKind),
    );
    if (kind != null) _lastKind = kind;
  }

  /// Abre un intento ya registrado para corregirlo o borrarlo.
  Future<void> _editAttempt(ApneaAttempt attempt) {
    return showAppSheet<void>(
      context,
      title: 'Editar intento',
      builder: (_) => _AddAttemptForm(
        sessionId: widget.sessionId,
        initialKind: attempt.kind,
        editing: attempt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attempts =
        ref.watch(apneaAttemptsProvider(widget.sessionId)).value ?? const [];

    return SessionScaffold(
      sessionId: widget.sessionId,
      title: 'Apnea',
      summary: switch (attempts.length) {
        0 => '',
        1 => '1 intento',
        final n => '$n intentos',
      },
      banner: const SafetyBanner(apneaSafetyMessage),
      isEmpty: attempts.isEmpty,
      emptyIcon: CupertinoIcons.wind,
      emptyTitle: 'Sin intentos todavía',
      emptyMessage: 'Toca "Agregar intento" para registrar el primero.',
      actionLabel: 'Agregar intento',
      onAction: _addAttempt,
      children: [
        const SectionHeader('Intentos'),
        CardGroup(
          children: [
            for (final (index, attempt) in attempts.indexed)
              _AttemptRow(
                number: index + 1,
                attempt: attempt,
                onTap: () => _editAttempt(attempt),
              ),
          ],
        ),
      ],
    );
  }
}

class _AttemptRow extends StatelessWidget {
  const _AttemptRow({
    required this.number,
    required this.attempt,
    required this.onTap,
  });

  final VoidCallback onTap;

  final int number;
  final ApneaAttempt attempt;

  @override
  Widget build(BuildContext context) {
    final time = attempt.durationMs == null
        ? null
        : formatDurationMs(attempt.durationMs!);
    final isStatic = attempt.kind == ApneaKind.static;

    return RecordRow(
      marker: RowNumber(number),
      onTap: onTap,
      title: isStatic ? time ?? '—' : '${attempt.distanceM} m',
      details: [
        [
          apneaKindLabel(attempt.kind),
          if (!isStatic && time != null) time,
        ].join(' · '),
      ],
    );
  }
}

class _AddAttemptForm extends ConsumerStatefulWidget {
  const _AddAttemptForm({
    required this.sessionId,
    required this.initialKind,
    this.editing,
  });

  /// El intento que se está corrigiendo; `null` si es nuevo.
  final ApneaAttempt? editing;

  final String sessionId;
  final ApneaKind initialKind;

  @override
  ConsumerState<_AddAttemptForm> createState() => _AddAttemptFormState();
}

class _AddAttemptFormState extends ConsumerState<_AddAttemptForm> {
  late ApneaKind _kind = widget.initialKind;
  late final _time = TextEditingController(
    text: widget.editing?.durationMs == null
        ? null
        : formatDurationMs(widget.editing!.durationMs!),
  );
  late final _distance = TextEditingController(
    text: widget.editing?.distanceM?.toString(),
  );
  String? _error;

  @override
  void dispose() {
    _time.dispose();
    _distance.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final isStatic = _kind == ApneaKind.static;
    final timeText = _time.text.trim();
    final time = parseDurationMs(timeText);
    final distance = int.tryParse(_distance.text.trim());

    String? error;
    if (isStatic && time == null) {
      error = 'Escribe el tiempo (por ejemplo, 2:30).';
    } else if (!isStatic && (distance == null || distance <= 0)) {
      error = 'Escribe la distancia en metros.';
    } else if (!isStatic && timeText.isNotEmpty && time == null) {
      error = 'El tiempo no es válido (por ejemplo, 1:05).';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    final repository = ref.read(trainingRepositoryProvider);
    final editing = widget.editing;
    final savedDistance = isStatic ? null : distance;
    if (editing == null) {
      await repository.addApneaAttempt(
        sessionId: widget.sessionId,
        kind: _kind,
        durationMs: time,
        distanceM: savedDistance,
      );
    } else {
      await repository.updateApneaAttempt(
        editing.id,
        kind: _kind,
        durationMs: time,
        distanceM: savedDistance,
      );
    }
    if (mounted) Navigator.of(context).pop(_kind);
  }

  Future<void> _delete() async {
    await ref
        .read(trainingRepositoryProvider)
        .deleteApneaAttempt(widget.editing!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isStatic = _kind == ApneaKind.static;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SafetyBanner(apneaSafetyMessage),
        const SizedBox(height: 12),
        CupertinoSlidingSegmentedControl<ApneaKind>(
          groupValue: _kind,
          padding: const EdgeInsets.all(4),
          children: const {
            ApneaKind.static: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Estática'),
            ),
            ApneaKind.dynamic: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Dinámica'),
            ),
          },
          onValueChanged: (kind) {
            if (kind != null) setState(() => _kind = kind);
          },
        ),
        const SizedBox(height: 12),
        CardGroup(
          children: [
            if (!isStatic)
              FormRow(
                label: 'Distancia (m)',
                child: RowTextField(
                  key: const Key('distance'),
                  controller: _distance,
                  placeholder: '0',
                  keyboardType: TextInputType.number,
                ),
              ),
            FormRow(
              label: 'Tiempo',
              child: RowTextField(
                key: const Key('time'),
                controller: _time,
                placeholder: isStatic ? 'min:seg' : 'Opcional',
                keyboardType: TextInputType.datetime,
              ),
            ),
          ],
        ),
        if (_error != null) FormError(_error!),
        FormActions(
          saveLabel: widget.editing == null
              ? 'Guardar intento'
              : 'Guardar cambios',
          onSave: _save,
          deleteLabel: 'Borrar intento',
          onDelete: widget.editing == null ? null : _delete,
        ),
      ],
    );
  }
}
