import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../app/sync.dart';
import '../sync/sync_service.dart';
import 'formatting.dart';
import 'theme.dart';
import 'widgets.dart';

/// Conexión con el servidor de la casa (etapa 2): crear cuenta, iniciar
/// sesión y sincronizar.
class ServerScreen extends ConsumerStatefulWidget {
  const ServerScreen({super.key, this.loginOnly = false});

  /// Desde la bienvenida: solo iniciar sesión en una cuenta que ya existe.
  final bool loginOnly;

  @override
  ConsumerState<ServerScreen> createState() => _ServerScreenState();
}

class _ServerScreenState extends ConsumerState<ServerScreen> {
  late final _address = TextEditingController(
    text: ref.read(syncControllerProvider).address,
  );
  late final _username = TextEditingController(
    text: ref.read(syncControllerProvider).username,
  );
  final _password = TextEditingController();

  @override
  void dispose() {
    _address.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool create}) async {
    final controller = ref.read(syncControllerProvider.notifier);
    if (create) {
      await controller.register(_address.text, _username.text, _password.text);
    } else {
      await controller.login(_address.text, _username.text, _password.text);
    }
    if (!mounted) return;
    final status = ref.read(syncControllerProvider);
    if (status.connected && status.error == null) {
      _password.clear();
      // Desde la bienvenida, al bajar los datos ya existe el usuario y la app
      // pasa sola a las pestañas; esta pantalla sobra.
      if (widget.loginOnly) Navigator.of(context).pop();
    }
  }

  Future<void> _logout() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Tus datos se quedan en este teléfono; solo deja de sincronizar.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(syncControllerProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(syncControllerProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Servidor'),
        previousPageTitle: 'Atrás',
        border: null,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            screenPadding,
            0,
            screenPadding,
            32,
          ),
          children: status.connected
              ? _connected(context, status)
              : _form(context, status),
        ),
      ),
    );
  }

  List<Widget> _connected(BuildContext context, SyncStatus status) {
    final secondary = textStyle(context, color: CupertinoColors.secondaryLabel);
    final report = status.lastReport;
    return [
      const SectionHeader('Conectado'),
      CardGroup(
        children: [
          FormRow(
            label: 'Usuario',
            child: Text(status.username ?? '', style: secondary),
          ),
          FormRow(
            label: 'Servidor',
            child: Text(
              status.address ?? '',
              style: secondary,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          FormRow(
            label: 'Última vez',
            child: Text(
              status.lastSyncedAt == null
                  ? 'Nunca'
                  : formatDateTime(status.lastSyncedAt!),
              key: const Key('lastSynced'),
              style: secondary,
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      PrimaryButton(
        key: const Key('syncNow'),
        label: status.busy ? 'Sincronizando…' : 'Sincronizar ahora',
        icon: CupertinoIcons.arrow_2_circlepath,
        onPressed: status.busy
            ? null
            : () => ref.read(syncControllerProvider.notifier).syncNow(),
      ),
      if (report != null)
        _Note(describeReport(report), key: const Key('syncResult')),
      if (status.error != null) FormError(status.error!),
      const _Note(
        'La app también sincroniza sola al abrirla, si estás en el mismo '
        'Wi-Fi que la Mac y el servidor está encendido.',
      ),
      const SizedBox(height: 28),
      CupertinoButton(
        onPressed: status.busy ? null : _logout,
        child: Text(
          'Cerrar sesión',
          style: textStyle(
            context,
            weight: FontWeight.w600,
            color: CupertinoColors.destructiveRed,
          ),
        ),
      ),
    ];
  }

  List<Widget> _form(BuildContext context, SyncStatus status) {
    final hasUser = ref.watch(currentUserProvider).value != null;
    final canCreate = !widget.loginOnly && hasUser;
    return [
      const SizedBox(height: 8),
      Text(
        widget.loginOnly
            ? 'Entra con tu cuenta para bajar tus datos del servidor de tu '
                  'Mac.'
            : 'Conecta la app con el servidor de tu Mac para respaldar tus '
                  'datos y usarlos en otro iPhone.',
        style: textStyle(
          context,
          size: 15,
          color: CupertinoColors.secondaryLabel,
        ),
      ),
      const SectionHeader('Servidor'),
      _Field(
        key: const Key('serverAddress'),
        controller: _address,
        // Android no siempre resuelve los nombres .local: ahí se pide la IP.
        placeholder: Platform.isAndroid
            ? '192.168.1.20'
            : 'nombre-de-tu-mac.local',
        keyboardType: TextInputType.url,
      ),
      _Note(
        Platform.isAndroid
            ? 'Escribe la IP de la Mac. La encuentras en la Mac, en Ajustes '
                  'del Sistema, Wi-Fi, Detalles. El servidor tiene que estar '
                  'encendido.'
            : 'Lo encuentras en la Mac, en Ajustes del Sistema, General, '
                  'Compartir: "Nombre del host local". El servidor tiene que '
                  'estar encendido.',
      ),
      const SectionHeader('Cuenta'),
      _Field(
        key: const Key('serverUsername'),
        controller: _username,
        placeholder: 'Usuario',
      ),
      const SizedBox(height: 10),
      _Field(
        key: const Key('serverPassword'),
        controller: _password,
        placeholder: 'Contraseña (mínimo 8)',
        obscure: true,
      ),
      if (status.error != null) FormError(status.error!),
      const SizedBox(height: 20),
      if (status.busy)
        const Padding(
          padding: EdgeInsets.all(14),
          child: CupertinoActivityIndicator(),
        )
      else if (canCreate) ...[
        PrimaryButton(
          key: const Key('createAccount'),
          label: 'Crear cuenta',
          onPressed: () => _submit(create: true),
        ),
        const SizedBox(height: 10),
        SecondaryButton(
          key: const Key('login'),
          label: 'Ya tengo cuenta',
          onPressed: () => _submit(create: false),
        ),
        const _Note(
          'Crear cuenta sube los datos de este teléfono. "Ya tengo cuenta" es '
          'para volver a entrar con la misma persona.',
        ),
      ] else
        PrimaryButton(
          key: const Key('login'),
          label: 'Iniciar sesión',
          onPressed: () => _submit(create: false),
        ),
    ];
  }
}

/// El resultado de una sincronización, en palabras.
String describeReport(SyncReport report) {
  final parts = [
    if (report.pushed > 0)
      report.pushed == 1
          ? '1 cambio subido'
          : '${report.pushed} cambios subidos',
    if (report.pulled > 0)
      report.pulled == 1
          ? '1 cambio recibido'
          : '${report.pulled} cambios recibidos',
  ];
  final problems = report.rejected + report.failed;
  final summary = parts.isEmpty ? 'Todo estaba al día' : parts.join(' y ');
  return problems == 0
      ? 'Listo: $summary.'
      : 'Listo: $summary. $problems no se pudieron sincronizar; revisa que '
            'la hora del teléfono sea correcta y que la app esté actualizada.';
}

class _Field extends StatelessWidget {
  const _Field({
    super.key,
    required this.controller,
    required this.placeholder,
    this.keyboardType,
    this.obscure = false,
  });

  final TextEditingController controller;
  final String placeholder;
  final TextInputType? keyboardType;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      keyboardType: keyboardType,
      obscureText: obscure,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.none,
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
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text, {super.key});

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
