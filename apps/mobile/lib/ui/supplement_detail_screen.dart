import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/notifications.dart';
import '../app/providers.dart';
import 'formatting.dart';
import 'supplement_forms.dart';
import 'theme.dart';
import 'widgets.dart';

/// Detalle de un suplemento: existencias, predicción, adherencia y todos sus
/// movimientos (compras, tomas y ajustes).
class SupplementDetailScreen extends ConsumerWidget {
  const SupplementDetailScreen({
    super.key,
    required this.userId,
    required this.supplementId,
  });

  final String userId;
  final String supplementId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref
        .watch(supplementsProvider(userId))
        .value
        ?.where((v) => v.supplement.id == supplementId)
        .firstOrNull;
    if (view == null) {
      // Recién borrado, o aún cargando.
      return const CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(previousPageTitle: 'Atrás'),
        child: SizedBox.shrink(),
      );
    }

    final repository = ref.read(supplementRepositoryProvider);
    final supplement = view.supplement;
    final (title, detail) = splitName(supplement.name);
    final unit = supplement.unitLabel;
    final now = DateTime.now();
    final status = view.statusAt(now);
    final secondary = textStyle(
      context,
      size: 13,
      color: CupertinoColors.secondaryLabel,
    );

    // Compras, tomas y ajustes en una sola lista, de lo más reciente a lo
    // más antiguo.
    final movements = <_Movement>[
      for (final p in view.purchases)
        (
          at: p.purchasedAt,
          label: p.note == null ? 'Compra' : 'Compra · ${p.note}',
          amount: p.quantity,
          delete: () => repository.deletePurchase(p.id),
        ),
      for (final i in view.intakes)
        (
          at: i.takenAt,
          label: i.isAdjustment ? 'Ajuste de existencias' : 'Toma',
          amount: -i.amount,
          delete: () => repository.deleteIntake(i.id),
        ),
    ]..sort((a, b) => b.at.compareTo(a.at));

    void openSheet(String title, Widget form) =>
        showAppSheet<void>(context, title: title, builder: (_) => form);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        previousPageTitle: 'Atrás',
        border: null,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => openSheet(
            'Editar suplemento',
            SupplementForm(
              isEditing: true,
              name: supplement.name,
              unitLabel: unit,
              dailyDose: supplement.dailyDose,
              timing: supplement.timing,
              restockLeadDays: supplement.restockLeadDays,
              reminderMinute: supplement.reminderMinute,
              onEnableReminder: () =>
                  ref.read(notificationSchedulerProvider).requestPermission(),
              onSave: (data) => repository.updateSupplement(
                supplement.id,
                name: data.name,
                unitLabel: data.unitLabel,
                dailyDose: data.dailyDose,
                timing: data.timing,
                restockLeadDays: data.restockLeadDays,
                reminderMinute: data.reminderMinute,
              ),
              onDelete: () async {
                // Se sale del detalle antes de que el suplemento desaparezca.
                Navigator.of(context).pop();
                await repository.deleteSupplement(supplement.id);
              },
            ),
          ),
          child: const Text('Editar'),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  screenPadding,
                  8,
                  screenPadding,
                  24,
                ),
                children: [
                  // El nombre completo, que en la barra no cabe.
                  Text(
                    title,
                    style: textStyle(
                      context,
                      size: 26,
                      weight: FontWeight.w700,
                    ),
                  ),
                  if (detail != null)
                    Text(
                      detail,
                      style: textStyle(
                        context,
                        size: 15,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          label: 'Existencias',
                          value: formatQuantity(status.stock, unit),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Stat(
                          label: 'Alcanza',
                          value: status.stock <= 0
                              ? '—'
                              : formatDaysLeft(status.daysLeft),
                          highlight: status.needsRestock,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          label: 'Se acaba',
                          value: status.runOutDate == null
                              ? '—'
                              : formatShortDate(status.runOutDate!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Stat(
                          label: 'Adherencia · 30 días',
                          value: status.adherence == null
                              ? '—'
                              : '${(status.adherence! * 100).round()} %',
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                    child: Text(
                      status.usesActualRate
                          ? 'Predicción con tu consumo real: '
                                '${formatQuantity(status.dailyRate, unit)} al '
                                'día (la dosis indicada es '
                                '${formatQuantity(supplement.dailyDose, unit)}).'
                          : 'Predicción con la dosis indicada: '
                                '${formatQuantity(supplement.dailyDose, unit)} '
                                'al día. Tras una semana de registros usará '
                                'tu consumo real.',
                      style: secondary,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                    child: Text(
                      switch (supplement.reminderMinute) {
                        null => 'Sin recordatorio diario. Actívalo en Editar.',
                        final minute =>
                          'Recordatorio diario a las '
                              '${formatMinuteOfDay(minute)}.',
                      },
                      key: const Key('reminderSummary'),
                      style: secondary,
                    ),
                  ),
                  if (supplement.timing case final timing?)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                      child: Text(timing, style: secondary),
                    ),
                  const SizedBox(height: 16),
                  CardGroup(
                    children: [
                      _ActionRow(
                        icon: CupertinoIcons.cart,
                        label: 'Registrar compra',
                        onPressed: () => openSheet(
                          'Nueva compra',
                          QuantityForm(
                            label: 'Cantidad',
                            unitLabel: unit,
                            saveLabel: 'Guardar compra',
                            withNote: true,
                            onSave: (quantity, note) => repository.addPurchase(
                              supplement.id,
                              quantity: quantity,
                              note: note,
                            ),
                          ),
                        ),
                      ),
                      _ActionRow(
                        icon: CupertinoIcons.slider_horizontal_3,
                        label: 'Corregir existencias',
                        onPressed: () => openSheet(
                          'Corregir existencias',
                          QuantityForm(
                            label: 'Lo que queda',
                            unitLabel: unit,
                            saveLabel: 'Guardar',
                            allowZero: true,
                            initial: status.stock,
                            help:
                                'Escribe lo que realmente te queda. La '
                                'diferencia se anota como un ajuste y no '
                                'cuenta como toma.',
                            onSave: (quantity, _) => repository.adjustStock(
                              supplement.id,
                              actualStock: quantity,
                              now: DateTime.now(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SectionHeader('Movimientos'),
                  if (movements.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: resolveColor(context, cardColor),
                        borderRadius: BorderRadius.circular(cardRadius),
                      ),
                      child: Text(
                        'Sin compras ni tomas registradas.',
                        style: textStyle(
                          context,
                          color: CupertinoColors.secondaryLabel,
                        ),
                      ),
                    )
                  else
                    CardGroup(
                      children: [
                        for (final movement in movements)
                          _MovementRow(movement: movement, unit: unit),
                      ],
                    ),
                ],
              ),
            ),
            BottomActionBar(
              child: PrimaryButton(
                label: status.takenToday
                    ? 'Registrar otra toma'
                    : 'Registrar toma de hoy',
                onPressed: () => repository.logIntake(supplement.id),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef _Movement = ({
  DateTime at,
  String label,
  double amount,
  Future<void> Function() delete,
});

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;

  /// Resalta el dato en naranja (queda poco).
  final bool highlight;

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
              style: textStyle(
                context,
                size: 24,
                weight: FontWeight.w700,
                color: highlight
                    ? CupertinoColors.systemOrange
                    : CupertinoColors.label,
              ),
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

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onPressed: onPressed,
      child: Row(
        children: [
          Icon(icon, size: 20, color: resolveColor(context, accentColor)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: textStyle(context))),
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

/// Un movimiento del inventario. Se toca para borrarlo.
class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.movement, required this.unit});

  final _Movement movement;
  final String unit;

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('¿Borrar este movimiento?'),
        content: const Text('Las existencias se recalculan.'),
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
    if (confirmed == true) await movement.delete();
  }

  @override
  Widget build(BuildContext context) {
    final isEntry = movement.amount > 0;
    // Raya corta y no el signo menos tipográfico: la fuente de la app no
    // trae ese carácter.
    final sign = isEntry ? '+' : '–';
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onPressed: () => _confirmDelete(context),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(movement.label, style: textStyle(context)),
                Text(
                  formatDateTime(movement.at),
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
            '$sign${formatQuantity(movement.amount.abs(), unit)}',
            style: textStyle(
              context,
              weight: FontWeight.w600,
              color: isEntry
                  ? CupertinoColors.systemGreen
                  : CupertinoColors.label,
            ),
          ),
        ],
      ),
    );
  }
}
