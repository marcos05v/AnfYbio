import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/backup.dart';
import '../app/providers.dart';
import '../data/export/backup_importer.dart';
import 'server_screen.dart';
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

  /// Restaura un respaldo. Solo se ofrece aquí, antes de que existan datos.
  Future<void> _restore() async {
    String? failure;
    try {
      final json = await ref.read(backupPickerProvider)();
      if (json == null) return; // se canceló el selector
      // Al importarse el usuario, la app pasa sola a la pantalla de sesiones.
      await ref.read(backupImporterProvider).import(json);
    } on BackupImportException catch (error) {
      failure = error.message;
    } catch (_) {
      failure = 'No se pudo leer el archivo.';
    }
    if (failure == null || !mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('No se pudo restaurar'),
        content: Text(failure!),
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
              CupertinoButton(
                key: const Key('welcomeLogin'),
                onPressed: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (_) => const ServerScreen(loginOnly: true),
                  ),
                ),
                child: const Text('Ya tengo cuenta en el servidor'),
              ),
              CupertinoButton(
                onPressed: _restore,
                child: const Text('Restaurar un respaldo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
