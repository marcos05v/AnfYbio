import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/database.dart';
import '../data/repositories/supplement_repository.dart';
import '../domain/supplement_inventory.dart';
import 'formatting.dart';
import 'supplement_detail_screen.dart';
import 'supplement_forms.dart';
import 'theme.dart';
import 'widgets.dart';

/// Pestaña de suplementos: inventario, tomas del día y avisos de reabasto.
class SupplementsScreen extends ConsumerWidget {
  const SupplementsScreen({super.key, required this.user});

  final User user;

  /// Abre el formulario de alta, opcionalmente con los datos de la guía.
  void _add(BuildContext context, WidgetRef ref, {SupplementGuideline? from}) {
    final dose = parseDose(from?.dose);
    showAppSheet<void>(
      context,
      title: 'Nuevo suplemento',
      builder: (_) => SupplementForm(
        name: from?.name,
        unitLabel: dose?.unit,
        dailyDose: dose?.amount,
        timing: from?.timing,
        onSave: (data) => ref
            .read(supplementRepositoryProvider)
            .addSupplement(
              userId: user.id,
              name: data.name,
              unitLabel: data.unitLabel,
              dailyDose: data.dailyDose,
              timing: data.timing,
              restockLeadDays: data.restockLeadDays,
              initialQuantity: data.initialQuantity,
            ),
      ),
    );
  }

  /// Deja elegir un suplemento de la guía del plan para darlo de alta.
  Future<void> _addFromPlan(
    BuildContext context,
    WidgetRef ref,
    List<SupplementGuideline> guidelines,
  ) async {
    final chosen = await showAppSheet<SupplementGuideline>(
      context,
      title: 'De la guía de tu plan',
      builder: (context) => CardGroup(
        children: [
          for (final guideline in guidelines)
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop(guideline),
              child: SupplementTile(name: guideline.name, dose: guideline.dose),
            ),
        ],
      ),
    );
    if (chosen != null && context.mounted) _add(context, ref, from: chosen);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supplementsProvider(user.id));
    final views = state.value ?? const <SupplementView>[];
    final now = DateTime.now();

    // Suplementos de la guía del plan que aún no están en el inventario.
    final existing = {for (final v in views) v.supplement.name.toLowerCase()};
    final guidelines = [
      for (final g
          in ref.watch(activePlanProvider(user.id)).value?.supplements ??
              const <SupplementGuideline>[])
        if (!existing.contains(g.name.toLowerCase())) g,
    ];

    final restock = [
      for (final view in views)
        if (view.statusAt(now).needsRestock) view,
    ];

    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('Suplementos'),
            border: null,
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _add(context, ref),
              child: const Icon(
                CupertinoIcons.add_circled,
                semanticLabel: 'Agregar suplemento',
              ),
            ),
          ),
          if (views.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: state.isLoading
                  ? const Center(child: CupertinoActivityIndicator())
                  : _NoSupplements(
                      hasGuide: guidelines.isNotEmpty,
                      onAdd: () => _add(context, ref),
                      onAddFromPlan: () =>
                          _addFromPlan(context, ref, guidelines),
                    ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                screenPadding,
                0,
                screenPadding,
                32,
              ),
              sliver: SliverList.list(
                children: [
                  if (restock.isNotEmpty) ...[
                    _RestockBanner(views: restock, now: now),
                    const SizedBox(height: 12),
                  ],
                  for (final view in views) ...[
                    _SupplementCard(user: user, view: view, now: now),
                    const SizedBox(height: 10),
                  ],
                  if (guidelines.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    OutlineAddButton(
                      label: 'Agregar desde mi plan',
                      onPressed: () => _addFromPlan(context, ref, guidelines),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _NoSupplements extends StatelessWidget {
  const _NoSupplements({
    required this.hasGuide,
    required this.onAdd,
    required this.onAddFromPlan,
  });

  final bool hasGuide;
  final VoidCallback onAdd;
  final VoidCallback onAddFromPlan;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(screenPadding + 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.capsule,
            size: 44,
            color: resolveColor(context, CupertinoColors.tertiaryLabel),
          ),
          const SizedBox(height: 14),
          Text(
            'Sin suplementos todavía',
            style: textStyle(context, size: 20, weight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Registra lo que tomas y cuánto tienes: la app te dirá cuándo '
            'se acaba y te avisará para reabastecer.',
            textAlign: TextAlign.center,
            style: textStyle(
              context,
              size: 15,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
          const SizedBox(height: 24),
          if (hasGuide) ...[
            PrimaryButton(
              label: 'Agregar desde mi plan',
              onPressed: onAddFromPlan,
            ),
            const SizedBox(height: 10),
            SecondaryButton(label: 'Agregar otro', onPressed: onAdd),
          ] else
            PrimaryButton(label: 'Agregar suplemento', onPressed: onAdd),
        ],
      ),
    );
  }
}

/// Aviso con los suplementos que se acaban dentro de su plazo configurado.
class _RestockBanner extends StatelessWidget {
  const _RestockBanner({required this.views, required this.now});

  final List<SupplementView> views;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final lines = [
      for (final view in views)
        switch (view.statusAt(now)) {
          final s when s.stock <= 0 =>
            '${view.supplement.name}: sin existencias',
          final s =>
            '${view.supplement.name}: alcanza ${formatDaysLeft(s.daysLeft)}',
        },
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFC2410C),
        borderRadius: BorderRadius.circular(cardRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            CupertinoIcons.cart_fill,
            size: 20,
            color: CupertinoColors.white,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hay que reabastecer',
                  style: textStyle(
                    context,
                    size: 15,
                    weight: FontWeight.w700,
                    color: CupertinoColors.white,
                  ),
                ),
                for (final line in lines)
                  Text(
                    line,
                    style: textStyle(
                      context,
                      size: 14,
                      color: CupertinoColors.white,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SupplementCard extends ConsumerWidget {
  const _SupplementCard({
    required this.user,
    required this.view,
    required this.now,
  });

  final User user;
  final SupplementView view;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplement = view.supplement;
    final status = view.statusAt(now);
    final secondary = textStyle(
      context,
      size: 13,
      color: CupertinoColors.secondaryLabel,
    );
    final accent = resolveColor(context, accentColor);

    return Container(
      decoration: BoxDecoration(
        color: resolveColor(context, cardColor),
        borderRadius: BorderRadius.circular(cardRadius),
      ),
      child: Row(
        children: [
          Expanded(
            child: CupertinoButton(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              onPressed: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => SupplementDetailScreen(
                    userId: user.id,
                    supplementId: supplement.id,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SupplementIcon(supplement.name),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          supplement.name,
                          style: textStyle(context, weight: FontWeight.w600),
                        ),
                        Text(
                          status.stock <= 0
                              ? 'Sin existencias'
                              : 'Quedan '
                                    '${formatQuantity(status.stock, supplement.unitLabel)}'
                                    ' · alcanza '
                                    '${formatDaysLeft(status.daysLeft)}',
                          style: textStyle(
                            context,
                            size: 14,
                            weight: FontWeight.w500,
                            color: status.needsRestock
                                ? CupertinoColors.systemOrange
                                : CupertinoColors.label,
                          ),
                        ),
                        if (status.runOutDate case final date?)
                          Text(
                            'Se acaba el ${formatShortDate(date)}',
                            style: secondary,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: status.takenToday
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.checkmark_circle_fill,
                        size: 20,
                        color: resolveColor(
                          context,
                          CupertinoColors.systemGreen,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Tomado',
                        style: textStyle(
                          context,
                          size: 14,
                          weight: FontWeight.w600,
                          color: CupertinoColors.systemGreen,
                        ),
                      ),
                    ],
                  )
                : CupertinoButton(
                    key: Key('take-${supplement.name}'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    minimumSize: Size.zero,
                    color: accent,
                    borderRadius: BorderRadius.circular(999),
                    onPressed: () => ref
                        .read(supplementRepositoryProvider)
                        .logIntake(supplement.id),
                    child: Text(
                      'Tomar',
                      style: textStyle(
                        context,
                        size: 14,
                        weight: FontWeight.w600,
                        color: onAccentColor,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
