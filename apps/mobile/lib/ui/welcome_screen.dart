import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import 'theme.dart';
import 'widgets.dart';

/// Primera apertura: pide el nombre y crea el usuario local.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_name.text.trim().isEmpty) return;
    // Al crearse el usuario, currentUserProvider emite y la app cambia sola
    // a la pantalla de sesiones.
    await ref.read(userRepositoryProvider).createUser(_name.text);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(screenPadding + 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: resolveColor(context, accentColor),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    CupertinoIcons.drop_fill,
                    size: 32,
                    color: resolveColor(context, onAccentColor),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'AnfYbio',
                style: textStyle(context, size: 36, weight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Fuerza y resistencia en un solo registro.',
                style: textStyle(
                  context,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
              const SizedBox(height: 36),
              Text(
                '¿Cómo te llamas?',
                style: textStyle(context, weight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              CupertinoTextField(
                key: const Key('name'),
                controller: _name,
                placeholder: 'Tu nombre',
                autofocus: true,
                maxLength: 50,
                textCapitalization: TextCapitalization.words,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  color: resolveColor(context, cardColor),
                  borderRadius: BorderRadius.circular(cardRadius),
                ),
                style: textStyle(context),
                onSubmitted: (_) => _start(),
              ),
              const Spacer(flex: 2),
              PrimaryButton(label: 'Empezar', onPressed: _start),
            ],
          ),
        ),
      ),
    );
  }
}
