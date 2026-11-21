import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/appearance.dart';
import '../app/notifications.dart';
import '../app/providers.dart';
import '../data/repositories/supplement_repository.dart';
import '../domain/supplement_notifications.dart';
import 'formatting.dart';

/// Mantiene programadas las notificaciones de suplementos: las rehace cada
/// vez que cambia el inventario y cada vez que la app vuelve a primer plano
/// (por ejemplo, al día siguiente).
class NotificationSync extends ConsumerStatefulWidget {
  const NotificationSync({
    super.key,
    required this.userId,
    required this.child,
  });

  final String userId;
  final Widget child;

  @override
  ConsumerState<NotificationSync> createState() => _NotificationSyncState();
}

class _NotificationSyncState extends ConsumerState<NotificationSync> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _reschedule);
    ref.listenManual(supplementsProvider(widget.userId), (_, next) {
      if (next.value case final views?) _schedule(views);
    }, fireImmediately: true);
    // Cambiar el sonido reprograma todo con el nuevo.
    ref.listenManual(notificationSoundProvider, (_, _) => _reschedule());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _reschedule() {
    final views = ref.read(supplementsProvider(widget.userId)).value;
    if (views != null) _schedule(views);
  }

  Future<void> _schedule(List<SupplementView> views) {
    final now = DateTime.now();
    final leadDays = <SupplementForNotifications, int>{};
    final supplements = [
      for (final view in views)
        () {
          final s = view.supplement;
          final item = SupplementForNotifications(
            id: s.id,
            name: splitName(s.name).$1,
            doseLabel: formatQuantity(s.dailyDose, s.unitLabel),
            timing: s.timing,
            reminderMinute: s.reminderMinute,
            status: view.statusAt(now),
            tracksStock: view.hasInventory,
          );
          leadDays[item] = s.restockLeadDays;
          return item;
        }(),
    ];
    return ref
        .read(notificationSchedulerProvider)
        .replaceAll(
          planSupplementNotifications(
            supplements: supplements,
            now: now,
            restockLeadDays: (s) => leadDays[s]!,
          ),
          soundFile: ref.read(notificationSoundProvider).fileName,
        );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
