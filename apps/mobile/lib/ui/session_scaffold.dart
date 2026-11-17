import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/database.dart';
import 'formatting.dart';
import 'theme.dart';
import 'widgets.dart';

/// Estructura común de las pantallas de sesión, sea del tipo que sea:
/// encabezado con la fecha, contenido, menú para borrar y barra inferior
/// con "Terminar" y la acción principal.
class SessionScaffold extends ConsumerWidget {
  const SessionScaffold({
    super.key,
    required this.sessionId,
    required this.title,
    required this.summary,
    required this.isEmpty,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.children,
    required this.actionLabel,
    required this.onAction,
    this.actionIcon = CupertinoIcons.add,
    this.banner,
  });

  final String sessionId;
  final String title;

  /// Resumen corto para el encabezado ("5 series"); vacío si no hay nada.
  final String summary;
  final bool isEmpty;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;
  final List<Widget> children;
  final String actionLabel;
  final IconData? actionIcon;
  final VoidCallback onAction;

  /// Aviso fijo bajo el encabezado, siempre visible.
  final Widget? banner;

  Future<void> _finish(
    BuildContext context,
    WidgetRef ref,
    Session session,
  ) async {
    final result = await showAppSheet<({int durationS, int rpe})>(
      context,
      title: 'Terminar sesión',
      builder: (_) => _FinishForm(session: session),
    );
    if (result == null) return;
    await ref
        .read(trainingRepositoryProvider)
        .finishSession(
          sessionId,
          durationS: result.durationS,
          sessionRpe: result.rpe,
        );
    if (context.mounted) Navigator.of(context).pop();
  }

  /// Menú "…" de la barra: acciones poco frecuentes o destructivas.
  Future<void> _showMenu(BuildContext context, WidgetRef ref) async {
    final delete = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Borrar sesión'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
      ),
    );
    if (delete != true || !context.mounted) return;

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('¿Borrar la sesión?'),
        content: const Text(
          'Se borrará también todo lo que registraste en ella.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final repository = ref.read(trainingRepositoryProvider);
    // Se sale primero: al borrarse, la sesión deja de existir para esta pantalla.
    Navigator.of(context).pop();
    await repository.deleteSession(sessionId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider(sessionId)).value;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(title),
        previousPageTitle: 'Atrás',
        border: null,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showMenu(context, ref),
          child: const Icon(
            CupertinoIcons.ellipsis_circle,
            semanticLabel: 'Más opciones',
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                screenPadding,
                8,
                screenPadding,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (session != null)
                    _SessionHeader(session: session, summary: summary),
                  if (banner != null) ...[const SizedBox(height: 14), banner!],
                ],
              ),
            ),
            Expanded(
              child: isEmpty
                  ? _EmptyState(
                      icon: emptyIcon,
                      title: emptyTitle,
                      message: emptyMessage,
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: screenPadding,
                      ),
                      children: [...children, const SizedBox(height: 24)],
                    ),
            ),
            BottomActionBar(
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: SecondaryButton(
                      label: session?.durationS == null
                          ? 'Terminar'
                          : 'Editar cierre',
                      onPressed: session == null
                          ? null
                          : () => _finish(context, ref, session),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: PrimaryButton(
                      label: actionLabel,
                      icon: actionIcon,
                      onPressed: onAction,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Encabezado de la sesión: fecha grande y una línea con su estado.
class _SessionHeader extends StatelessWidget {
  const _SessionHeader({required this.session, required this.summary});

  final Session session;
  final String summary;

  @override
  Widget build(BuildContext context) {
    final start = formatTime(session.startedAt);
    final status = [
      if (session.durationS == null)
        'Empezó a las $start'
      else ...[
        start,
        // Minutos redondos como "60 min"; con segundos, como reloj ("26:30").
        session.durationS! % 60 == 0
            ? '${session.durationS! ~/ 60} min'
            : formatDurationMs(session.durationS! * 1000),
        'RPE ${session.sessionRpe}',
      ],
      if (summary.isNotEmpty) summary,
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatLongDate(session.startedAt),
          style: textStyle(context, size: 26, weight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          status,
          style: textStyle(
            context,
            size: 15,
            color: CupertinoColors.secondaryLabel,
          ),
        ),
      ],
    );
  }
}

/// Estado vacío: explica qué hacer, centrado en el espacio libre.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
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
              icon,
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

/// Pide la duración y el RPE de la sesión completa (los dos datos del sRPE).
class _FinishForm extends StatefulWidget {
  const _FinishForm({required this.session});

  final Session session;

  @override
  State<_FinishForm> createState() => _FinishFormState();
}

class _FinishFormState extends State<_FinishForm> {
  late final TextEditingController _duration;
  late int _rpe;
  String? _error;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    // Propone el tiempo transcurrido desde el inicio; se puede corregir.
    final elapsed = DateTime.now().toUtc().difference(session.startedAt);
    final seconds = session.durationS;
    final text = seconds == null
        ? '${elapsed.inMinutes.clamp(1, 600)}'
        : seconds % 60 == 0
        ? '${seconds ~/ 60}'
        : formatDurationMs(seconds * 1000);
    _duration = TextEditingController(text: text);
    _rpe = session.sessionRpe ?? 7;
  }

  @override
  void dispose() {
    _duration.dispose();
    super.dispose();
  }

  void _save() {
    final durationS = parseSessionDurationS(_duration.text);
    if (durationS == null) {
      setState(
        () => _error = 'Escribe la duración: minutos (45) o min:seg (45:30).',
      );
      return;
    }
    Navigator.of(context).pop((durationS: durationS, rpe: _rpe));
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
              label: 'Duración',
              child: RowTextField(
                key: const Key('minutes'),
                controller: _duration,
                placeholder: 'min o min:seg',
                keyboardType: TextInputType.datetime,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          decoration: BoxDecoration(
            color: resolveColor(context, cardColor),
            borderRadius: BorderRadius.circular(cardRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Esfuerzo de la sesión',
                      style: textStyle(context),
                    ),
                  ),
                  Text(
                    '$_rpe · ${rpeLabel(_rpe)}',
                    style: textStyle(context, weight: FontWeight.w600),
                  ),
                ],
              ),
              CupertinoSlider(
                value: _rpe.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                onChanged: (value) => setState(() => _rpe = value.round()),
              ),
            ],
          ),
        ),
        if (_error != null) FormError(_error!),
        const SizedBox(height: 16),
        PrimaryButton(label: 'Guardar', onPressed: _save),
      ],
    );
  }
}
