import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/database.dart';
import '../data/tables/swim.dart';
import '../domain/pace.dart';
import 'formatting.dart';
import 'session_scaffold.dart';
import 'theme.dart';
import 'widgets.dart';

/// Lo último que se capturó, para proponerlo en el siguiente bloque.
typedef _LastBlock = ({SwimStroke stroke, String distance});

/// Registro de una sesión de natación: bloques por estilo con sus parciales.
class SwimSessionScreen extends ConsumerStatefulWidget {
  const SwimSessionScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<SwimSessionScreen> createState() => _SwimSessionScreenState();
}

class _SwimSessionScreenState extends ConsumerState<SwimSessionScreen> {
  _LastBlock? _last;

  Future<void> _addBlock(int? poolLengthM) async {
    final saved = await showAppSheet<_LastBlock>(
      context,
      title: 'Nuevo bloque',
      builder: (_) => _AddBlockForm(
        sessionId: widget.sessionId,
        poolLengthM: poolLengthM,
        initial: _last,
      ),
    );
    if (saved != null) _last = saved;
  }

  /// Abre un bloque ya registrado para corregirlo o borrarlo.
  Future<void> _editBlock(
    SwimInterval block,
    List<SwimLap> laps,
    int? poolLengthM,
  ) {
    return showAppSheet<void>(
      context,
      title: 'Editar bloque',
      builder: (_) => _AddBlockForm(
        sessionId: widget.sessionId,
        poolLengthM: poolLengthM,
        initial: null,
        editing: block,
        editingLaps: laps,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.sessionId;
    final pool = ref.watch(swimDetailProvider(id)).value?.poolLengthM;
    final blocks = ref.watch(swimIntervalsProvider(id)).value ?? const [];
    final laps = ref.watch(swimLapsProvider(id)).value ?? const [];
    final totalM = blocks.fold(0, (sum, b) => sum + b.distanceM);

    return SessionScaffold(
      sessionId: id,
      title: 'Natación',
      summary: [
        if (pool != null) 'Alberca de $pool m',
        if (blocks.isNotEmpty) formatDistance(totalM),
      ].join(' · '),
      isEmpty: blocks.isEmpty,
      emptyIcon: CupertinoIcons.drop,
      emptyTitle: 'Sin bloques todavía',
      emptyMessage:
          'Un bloque es una distancia nadada con un mismo estilo. '
          'Toca "Agregar bloque" para registrar el primero.',
      actionLabel: 'Agregar bloque',
      onAction: () => _addBlock(pool),
      children: [
        const SectionHeader('Bloques'),
        CardGroup(
          children: [
            for (final (index, block) in blocks.indexed)
              () {
                final blockLaps = [
                  for (final lap in laps)
                    if (lap.intervalId == block.id) lap,
                ];
                return _BlockRow(
                  number: index + 1,
                  block: block,
                  laps: blockLaps,
                  onTap: () => _editBlock(block, blockLaps, pool),
                );
              }(),
          ],
        ),
      ],
    );
  }
}

class _BlockRow extends StatelessWidget {
  const _BlockRow({
    required this.number,
    required this.block,
    required this.laps,
    required this.onTap,
  });

  final VoidCallback onTap;
  final int number;
  final SwimInterval block;
  final List<SwimLap> laps;

  @override
  Widget build(BuildContext context) {
    final pace = swimPaceSecondsPer100m(
      distanceM: block.distanceM,
      durationMs: block.durationMs,
    );
    return RecordRow(
      marker: RowNumber(number),
      onTap: onTap,
      title: '${block.distanceM} m · ${swimStrokeLabel(block.stroke)}',
      details: [
        [
          formatDurationMs(block.durationMs),
          if (pace != null) '${formatPace(pace)} /100 m',
        ].join(' · '),
        if (laps.isNotEmpty)
          'Parciales: ${laps.map((l) => formatDurationMs(l.splitMs)).join('  ')}',
      ],
    );
  }
}

class _AddBlockForm extends ConsumerStatefulWidget {
  const _AddBlockForm({
    required this.sessionId,
    required this.poolLengthM,
    required this.initial,
    this.editing,
    this.editingLaps = const [],
  });

  final String sessionId;
  final int? poolLengthM;
  final _LastBlock? initial;

  /// El bloque que se está corrigiendo, con sus parciales; `null` si es nuevo.
  final SwimInterval? editing;
  final List<SwimLap> editingLaps;

  @override
  ConsumerState<_AddBlockForm> createState() => _AddBlockFormState();
}

class _AddBlockFormState extends ConsumerState<_AddBlockForm> {
  late SwimStroke _stroke =
      widget.editing?.stroke ?? widget.initial?.stroke ?? SwimStroke.freestyle;
  late final _distance = TextEditingController(
    text: widget.editing?.distanceM.toString() ?? widget.initial?.distance,
  );
  late final _time = TextEditingController(
    text: widget.editing == null
        ? null
        : formatDurationMs(widget.editing!.durationMs),
  );
  late final _splits = TextEditingController(
    text: widget.editingLaps
        .map((lap) => formatDurationMs(lap.splitMs))
        .join(' '),
  );
  String? _error;

  @override
  void dispose() {
    _distance.dispose();
    _time.dispose();
    _splits.dispose();
    super.dispose();
  }

  Future<void> _pickStroke() async {
    final stroke = await showCupertinoModalPopup<SwimStroke>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Estilo'),
        actions: [
          for (final stroke in SwimStroke.values)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop(stroke),
              child: Text(swimStrokeLabel(stroke)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ),
    );
    if (stroke != null) setState(() => _stroke = stroke);
  }

  Future<void> _save() async {
    final distance = int.tryParse(_distance.text.trim());
    final splitTexts = _splits.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    final splits = [for (final text in splitTexts) parseDurationMs(text)];
    final pool = widget.poolLengthM;

    // Con parciales completos, el tiempo total se puede dejar vacío: es su suma.
    var time = parseDurationMs(_time.text);
    if (_time.text.trim().isEmpty &&
        splits.isNotEmpty &&
        !splits.contains(null)) {
      time = splits.fold<int>(0, (sum, ms) => sum + ms!);
    }

    String? error;
    if (distance == null || distance <= 0) {
      error = 'Escribe la distancia en metros.';
    } else if (splits.contains(null)) {
      error = 'Hay un parcial que no es un tiempo válido.';
    } else if (time == null) {
      error = 'Escribe el tiempo total (por ejemplo, 1:35).';
    } else if (splits.isNotEmpty &&
        pool != null &&
        splits.length * pool != distance) {
      final expected = distance / pool;
      error = distance % pool == 0
          ? 'Para $distance m en alberca de $pool m son ${expected.round()} '
                'parciales; escribiste ${splits.length}.'
          : '$distance m no es múltiplo de la alberca de $pool m; '
                'quita los parciales o corrige la distancia.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    final repository = ref.read(trainingRepositoryProvider);
    final editing = widget.editing;
    if (editing == null) {
      await repository.addSwimInterval(
        sessionId: widget.sessionId,
        stroke: _stroke,
        distanceM: distance!,
        durationMs: time!,
        lapSplitsMs: [for (final ms in splits) ms!],
      );
    } else {
      await repository.updateSwimInterval(
        editing.id,
        stroke: _stroke,
        distanceM: distance!,
        durationMs: time!,
        lapSplitsMs: [for (final ms in splits) ms!],
      );
    }
    if (!mounted) return;
    Navigator.of(context)
        .pop<_LastBlock>((stroke: _stroke, distance: _distance.text));
  }

  Future<void> _delete() async {
    await ref
        .read(trainingRepositoryProvider)
        .deleteSwimInterval(widget.editing!.id);
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
            PickerRow(
              key: const Key('stroke'),
              label: 'Estilo',
              value: swimStrokeLabel(_stroke),
              onPressed: _pickStroke,
            ),
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
              label: 'Tiempo total',
              child: RowTextField(
                key: const Key('time'),
                controller: _time,
                placeholder: 'min:seg',
                keyboardType: TextInputType.datetime,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        CupertinoTextField(
          key: const Key('splits'),
          controller: _splits,
          placeholder: 'Parciales por vuelta (opcional)',
          keyboardType: TextInputType.datetime,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: resolveColor(context, cardColor),
            borderRadius: BorderRadius.circular(cardRadius),
          ),
          style: textStyle(context),
          placeholderStyle: textStyle(
            context,
            color: CupertinoColors.placeholderText,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(
            'Un tiempo por vuelta, separados por espacios. '
            'Ejemplo: 23.5 24.1 24.8 25',
            style: textStyle(
              context,
              size: 13,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ),
        if (_error != null) FormError(_error!),
        const SizedBox(height: 16),
        PrimaryButton(
          label: widget.editing == null ? 'Guardar bloque' : 'Guardar cambios',
          onPressed: _save,
        ),
        if (widget.editing != null)
          DeleteButton(label: 'Borrar bloque', onConfirmed: _delete),
      ],
    );
  }
}
