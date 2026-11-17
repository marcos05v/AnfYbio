import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/appearance.dart';
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
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
              child: Text(
                '"Sistema" usa el modo claro u oscuro que tenga tu iPhone.',
                style: textStyle(
                  context,
                  size: 13,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
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
          ],
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
