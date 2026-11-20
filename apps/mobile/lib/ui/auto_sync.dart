import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/sync.dart';

/// Sincroniza en silencio al abrir la app y cada vez que vuelve a primer
/// plano, si hay sesión en el servidor (ADR-0020). Sin Wi-Fi de la casa o
/// con la Mac apagada simplemente no pasa nada.
class AutoSync extends ConsumerStatefulWidget {
  const AutoSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AutoSync> createState() => _AutoSyncState();
}

class _AutoSyncState extends ConsumerState<AutoSync> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _sync);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  void _sync() {
    if (mounted) ref.read(syncControllerProvider.notifier).syncQuietly();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
