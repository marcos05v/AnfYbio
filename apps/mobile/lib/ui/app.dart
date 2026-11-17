import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/appearance.dart';
import '../app/providers.dart';
import 'sessions_screen.dart';
import 'theme.dart';
import 'welcome_screen.dart';

class AnfybioApp extends ConsumerWidget {
  const AnfybioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = switch (ref.watch(appearanceProvider)) {
      AppAppearance.system => null,
      AppAppearance.light => Brightness.light,
      AppAppearance.dark => Brightness.dark,
    };
    return CupertinoApp(
      title: 'AnfYbio',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(brightness),
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const _Root(),
    );
  }
}

/// Muestra la bienvenida hasta que existe un usuario; después, las sesiones.
class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return user.when(
      loading: () => const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator()),
      ),
      error: (error, _) =>
          CupertinoPageScaffold(child: Center(child: Text('Error: $error'))),
      data: (user) =>
          user == null ? const WelcomeScreen() : SessionsScreen(user: user),
    );
  }
}
