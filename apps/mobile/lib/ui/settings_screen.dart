import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/appearance.dart';
import '../app/backup.dart';
import '../app/notifications.dart';
import '../data/database.dart';
import 'theme.dart';
import 'widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Ajustes'),
        previousPageTitle: 'Atrás',
        border: null,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: screenPadding),
          children: [
            const SectionHeader('Apariencia'),
            SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<AppAppearance>(
                groupValue: appearance,
                padding: const EdgeInsets.all(4),
                children: const {
                  AppAppearance.system: _Segment('Sistema'),
                  AppAppearance.light: _Segment('Claro'),
                  AppAppearance.dark: _Segment('Oscuro'),
                },
                onValueChanged: (value) {
                  if (value != null) {
                    ref.read(appearanceProvider.notifier).select(value);
                  }
                },
              ),
            ),
            const _Footnote(
              '"Sistema" usa el modo claro u oscuro que tenga tu iPhone.',
            ),
            const SectionHeader('Perfil'),
            CardGroup(
              children: [
                FormRow(
                  label: 'Nombre',
                  child: Text(
                    user.displayName,
                    style: textStyle(
                      context,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                ),
              ],
            ),
            const SectionHeader('Notificaciones'),
            const _NotificationSettings(),
            const _Footnote(
              'Al elegir un sonido llega una notificación de prueba. En cada '
              'recordatorio, desliza hacia abajo para ver el botón "Ya lo '
              'tomé": registra la toma sin abrir la app.',
            ),
            const SectionHeader('Datos'),
            CardGroup(children: [_ExportRow(userId: user.id)]),
            const _Footnote(
              'Guarda una copia de todos tus datos en un archivo. Hazlo antes '
              'de borrar la app o cambiar de teléfono.',
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Sonido de las notificaciones y una notificación de prueba.
class _NotificationSettings extends ConsumerWidget {
  const _NotificationSettings();

  /// Muestra la notificación de prueba; si no hay permiso, explica cómo darlo.
  Future<void> _test(BuildContext context, WidgetRef ref) async {
    final scheduler = ref.read(notificationSchedulerProvider);
    if (!await scheduler.requestPermission()) {
      if (!context.mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Notificaciones desactivadas'),
          content: const Text(
            'Actívalas en Ajustes del iPhone > Notificaciones > AnfYbio.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
      return;
    }
    await scheduler.showTest(
      soundFile: ref.read(notificationSoundProvider).fileName,
    );
  }

  Future<void> _pickSound(BuildContext context, WidgetRef ref) async {
    final current = ref.read(notificationSoundProvider);
    final chosen = await showCupertinoModalPopup<NotificationSound>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Sonido de las notificaciones'),
        actions: [
          for (final sound in NotificationSound.values)
            CupertinoActionSheetAction(
              isDefaultAction: sound == current,
              onPressed: () => Navigator.of(context).pop(sound),
              child: Text(sound.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ),
    );
    if (chosen == null) return;
    await ref.read(notificationSoundProvider.notifier).select(chosen);
    // Se escucha al elegirlo.
    if (context.mounted) await _test(context, ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sound = ref.watch(notificationSoundProvider);
    return CardGroup(
      children: [
        PickerRow(
          key: const Key('soundPicker'),
          label: 'Sonido',
          value: sound.label,
          onPressed: () => _pickSound(context, ref),
        ),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _test(context, ref),
          child: FormRow(
            label: 'Probar notificación',
            child: Icon(
              CupertinoIcons.bell,
              size: 20,
              color: resolveColor(context, accentColor),
            ),
          ),
        ),
      ],
    );
  }
}

/// Fila que genera el respaldo y abre la hoja de compartir.
class _ExportRow extends ConsumerStatefulWidget {
  const _ExportRow({required this.userId});

  final String userId;

  @override
  ConsumerState<_ExportRow> createState() => _ExportRowState();
}

class _ExportRowState extends ConsumerState<_ExportRow> {
  bool _exporting = false;

  Future<void> _export() async {
    // La hoja de compartir sale desde esta fila.
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;

    setState(() => _exporting = true);
    Object? failure;
    try {
      final backup = await ref
          .read(backupExporterProvider)
          .export(widget.userId);
      await ref.read(backupSharerProvider)(backup, origin: origin);
    } catch (error) {
      failure = error;
    }
    if (!mounted) return;
    // El indicador se apaga antes de mostrar el error, no después de cerrarlo.
    setState(() => _exporting = false);
    if (failure != null) await _showError(failure);
  }

  Future<void> _showError(Object error) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('No se pudo exportar'),
        content: Text('$error'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: _exporting ? null : _export,
      child: FormRow(
        label: 'Exportar respaldo',
        child: _exporting
            ? const CupertinoActivityIndicator()
            : Icon(
                CupertinoIcons.square_arrow_up,
                size: 20,
                color: resolveColor(context, accentColor),
              ),
      ),
    );
  }
}

class _Footnote extends StatelessWidget {
  const _Footnote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
      child: Text(
        text,
        style: textStyle(
          context,
          size: 13,
          color: CupertinoColors.secondaryLabel,
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(label, style: textStyle(context, size: 15)),
    );
  }
}
