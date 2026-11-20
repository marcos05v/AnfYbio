import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/catalog.dart';
import '../app/providers.dart';
import '../catalog/catalog_exercise.dart';
import '../catalog/exercise_matching.dart';
import '../data/database.dart';
import '../data/repositories/routine_repository.dart';
import 'catalog_exercise_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// Enlaza un ejercicio de la rutina con uno del catálogo: crea (o
/// reutiliza) el ejercicio con el que se registran sus series y guarda el
/// alias de su nombre (ADR-0015).
Future<void> linkRoutineExercise(
  WidgetRef ref, {
  required String userId,
  required RoutineExercise routineExercise,
  required String catalogId,
}) async {
  final exercise = await ref
      .read(routineRepositoryProvider)
      .exerciseFor(routineExercise.id);
  await ref
      .read(catalogLinkRepositoryProvider)
      .link(
        userId: userId,
        name: routineExercise.name,
        catalogId: catalogId,
        exerciseId: exercise.id,
      );
}

Future<void> unlinkRoutineExercise(
  WidgetRef ref, {
  required String userId,
  required RoutineExercise routineExercise,
}) {
  return ref
      .read(catalogLinkRepositoryProvider)
      .unlink(
        userId: userId,
        name: routineExercise.name,
        exerciseId: routineExercise.exerciseId,
      );
}

/// Abre el buscador y, si se elige un ejercicio, lo enlaza.
Future<void> pickAndLink(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required RoutineExercise routineExercise,
}) async {
  final chosen = await Navigator.of(context, rootNavigator: true).push(
    CupertinoPageRoute<CatalogExercise>(
      fullscreenDialog: true,
      builder: (_) => CatalogPickerScreen(
        title: routineExercise.name,
        initialQuery: routineExercise.name,
      ),
    ),
  );
  if (chosen == null) return;
  await linkRoutineExercise(
    ref,
    userId: userId,
    routineExercise: routineExercise,
    catalogId: chosen.id,
  );
}

/// Botón al lado de un ejercicio de la rutina: abre su ficha si está
/// enlazado, o el buscador si no.
class CatalogLinkButton extends ConsumerWidget {
  const CatalogLinkButton({
    super.key,
    required this.userId,
    required this.routineExercise,
  });

  final String userId;
  final RoutineExercise routineExercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aliases =
        ref.watch(exerciseAliasesProvider(userId)).value ?? const {};
    final catalogId = aliases[normalizeText(routineExercise.name)];
    final accent = resolveColor(context, accentColor);

    if (catalogId == null) {
      return CupertinoButton(
        key: Key('link-${routineExercise.id}'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        onPressed: () => pickAndLink(
          context,
          ref,
          userId: userId,
          routineExercise: routineExercise,
        ),
        child: Text(
          'Enlazar',
          style: textStyle(
            context,
            size: 14,
            weight: FontWeight.w600,
            color: accentColor,
          ),
        ),
      );
    }
    return CupertinoButton(
      key: Key('catalog-${routineExercise.id}'),
      padding: EdgeInsets.zero,
      minimumSize: const Size(40, 40),
      onPressed: () => Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) => CatalogExerciseScreen(
            catalogId: catalogId,
            onChange: () => pickAndLink(
              context,
              ref,
              userId: userId,
              routineExercise: routineExercise,
            ),
            onUnlink: () => unlinkRoutineExercise(
              ref,
              userId: userId,
              routineExercise: routineExercise,
            ),
          ),
        ),
      ),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          CupertinoIcons.photo,
          size: 18,
          color: accent,
          semanticLabel: 'Ver ejercicio',
        ),
      ),
    );
  }
}

/// Busca en el catálogo y devuelve el ejercicio elegido.
class CatalogPickerScreen extends ConsumerStatefulWidget {
  const CatalogPickerScreen({
    super.key,
    required this.title,
    required this.initialQuery,
  });

  final String title;
  final String initialQuery;

  @override
  ConsumerState<CatalogPickerScreen> createState() =>
      _CatalogPickerScreenState();
}

class _CatalogPickerScreenState extends ConsumerState<CatalogPickerScreen> {
  late final _query = TextEditingController(text: widget.initialQuery);
  late Future<List<CatalogMatch>> _results = _search();

  Future<List<CatalogMatch>> _search() =>
      ref.read(exerciseCatalogProvider).search(_query.text, limit: 30);

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final secondary = textStyle(
      context,
      size: 13,
      color: CupertinoColors.secondaryLabel,
    );

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Catálogo'),
        border: null,
        automaticallyImplyLeading: false,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                screenPadding,
                8,
                screenPadding,
                4,
              ),
              child: Text(
                'Elige el ejercicio que corresponde a "${widget.title}".',
                style: secondary.copyWith(fontSize: 15),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: screenPadding,
                vertical: 8,
              ),
              child: CupertinoSearchTextField(
                key: const Key('catalogSearch'),
                controller: _query,
                placeholder: 'Buscar en español o en inglés',
                // Con llaves: una flecha devolvería la búsqueda (un Future)
                // y setState lo rechaza.
                onChanged: (_) => setState(() {
                  _results = _search();
                }),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<CatalogMatch>>(
                future: _results,
                builder: (context, snapshot) {
                  final matches = snapshot.data;
                  if (matches == null) {
                    return const Center(child: CupertinoActivityIndicator());
                  }
                  if (matches.isEmpty) {
                    return Center(
                      child: Text('Sin resultados.', style: secondary),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      screenPadding,
                      4,
                      screenPadding,
                      24,
                    ),
                    children: [
                      CardGroup(
                        children: [
                          for (final match in matches)
                            CupertinoButton(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                12,
                                12,
                                12,
                              ),
                              onPressed: () =>
                                  Navigator.of(context).pop(match.exercise),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          match.exercise.name,
                                          style: textStyle(
                                            context,
                                            weight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          [
                                            match.exercise.nameEn,
                                            ?equipmentLabels[match
                                                .exercise
                                                .equipment],
                                          ].join(' · '),
                                          style: secondary,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (match.score >= confidentMatchScore)
                                    const StatusDot('Sugerido'),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Repasa los ejercicios de la rutina que aún no se enlazan: para cada uno
/// propone el más parecido del catálogo y el usuario lo confirma o elige
/// otro. Nada se enlaza sin confirmación.
class LinkReviewScreen extends ConsumerWidget {
  const LinkReviewScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routine = ref.watch(activeRoutineProvider(userId)).value;
    final aliases =
        ref.watch(exerciseAliasesProvider(userId)).value ?? const {};
    final pending = <RoutineExercise>[];
    final seen = <String>{};
    for (final day in routine?.days ?? const <RoutineDayView>[]) {
      for (final exercise in day.exercises) {
        final key = normalizeText(exercise.name);
        // Un mismo nombre en dos días se confirma una sola vez.
        if (!aliases.containsKey(key) && seen.add(key)) pending.add(exercise);
      }
    }

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Enlazar con el catálogo'),
        previousPageTitle: 'Atrás',
        border: null,
      ),
      child: SafeArea(
        child: pending.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.checkmark_circle_fill,
                        size: 44,
                        color: resolveColor(
                          context,
                          CupertinoColors.systemGreen,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Todos los ejercicios están enlazados',
                        textAlign: TextAlign.center,
                        style: textStyle(
                          context,
                          size: 20,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  screenPadding,
                  8,
                  screenPadding,
                  32,
                ),
                children: [
                  Text(
                    pending.length == 1
                        ? 'Falta 1 ejercicio. Confirma la sugerencia o elige '
                              'otro: la próxima vez ese nombre se enlaza solo.'
                        : 'Faltan ${pending.length} ejercicios. Confirma cada '
                              'sugerencia o elige otro: la próxima vez esos '
                              'nombres se enlazan solos.',
                    style: textStyle(
                      context,
                      size: 15,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (final exercise in pending) ...[
                    _ReviewRow(
                      key: ValueKey(exercise.id),
                      userId: userId,
                      routineExercise: exercise,
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
      ),
    );
  }
}

class _ReviewRow extends ConsumerStatefulWidget {
  const _ReviewRow({
    super.key,
    required this.userId,
    required this.routineExercise,
  });

  final String userId;
  final RoutineExercise routineExercise;

  @override
  ConsumerState<_ReviewRow> createState() => _ReviewRowState();
}

class _ReviewRowState extends ConsumerState<_ReviewRow> {
  late final Future<List<CatalogMatch>> _suggestion = ref
      .read(exerciseCatalogProvider)
      .search(widget.routineExercise.name, limit: 1);

  @override
  Widget build(BuildContext context) {
    final secondary = textStyle(
      context,
      size: 13,
      color: CupertinoColors.secondaryLabel,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: resolveColor(context, cardColor),
        borderRadius: BorderRadius.circular(cardRadius),
      ),
      child: FutureBuilder<List<CatalogMatch>>(
        future: _suggestion,
        builder: (context, snapshot) {
          final match = snapshot.data?.firstOrNull;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.routineExercise.name,
                style: textStyle(context, weight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              if (snapshot.data == null)
                const CupertinoActivityIndicator()
              else if (match == null)
                Text('Sin sugerencias: elígelo a mano.', style: secondary)
              else ...[
                Text('¿Es este?', style: secondary),
                Text(
                  match.exercise.name,
                  key: Key('suggestion-${widget.routineExercise.id}'),
                  style: textStyle(
                    context,
                    size: 16,
                    weight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
                Text(match.exercise.nameEn, style: secondary),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  if (match != null) ...[
                    Expanded(
                      child: CupertinoButton(
                        key: Key('confirm-${widget.routineExercise.id}'),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        color: accentColor,
                        borderRadius: BorderRadius.circular(12),
                        onPressed: () => linkRoutineExercise(
                          ref,
                          userId: widget.userId,
                          routineExercise: widget.routineExercise,
                          catalogId: match.exercise.id,
                        ),
                        child: Text(
                          'Sí, es este',
                          style: textStyle(
                            context,
                            size: 15,
                            weight: FontWeight.w600,
                            color: onAccentColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: CupertinoButton(
                      key: Key('other-${widget.routineExercise.id}'),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      color: resolveColor(
                        context,
                        CupertinoColors.systemBackground,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      onPressed: () => pickAndLink(
                        context,
                        ref,
                        userId: widget.userId,
                        routineExercise: widget.routineExercise,
                      ),
                      child: Text(
                        match == null ? 'Buscar' : 'Elegir otro',
                        style: textStyle(
                          context,
                          size: 15,
                          weight: FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Descarga de una vez las fotos de los ejercicios enlazados de la rutina,
/// para tenerlas sin internet en el gimnasio.
class DownloadImagesSheet extends ConsumerStatefulWidget {
  const DownloadImagesSheet({super.key, required this.catalogIds});

  final List<String> catalogIds;

  @override
  ConsumerState<DownloadImagesSheet> createState() =>
      _DownloadImagesSheetState();
}

class _DownloadImagesSheetState extends ConsumerState<DownloadImagesSheet> {
  int _done = 0;
  int _total = 0;
  int? _failed;

  @override
  void initState() {
    super.initState();
    _download();
  }

  Future<void> _download() async {
    final catalog = ref.read(exerciseCatalogProvider);
    final paths = <String>[
      for (final id in widget.catalogIds)
        ...?(await catalog.getById(id))?.images,
    ];
    if (!mounted) return;
    setState(() => _total = paths.length);
    final failed = await ref
        .read(exerciseImageStoreProvider)
        .downloadAll(
          paths,
          onProgress: (done, _) {
            if (mounted) setState(() => _done = done);
          },
        );
    if (mounted) setState(() => _failed = failed);
  }

  @override
  Widget build(BuildContext context) {
    final failed = _failed;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failed == null) ...[
          const CupertinoActivityIndicator(),
          const SizedBox(height: 12),
          Text(
            _total == 0 ? 'Preparando…' : 'Descargando $_done de $_total fotos',
            key: const Key('downloadProgress'),
            textAlign: TextAlign.center,
            style: textStyle(context),
          ),
        ] else
          Text(
            failed == 0
                ? 'Listo: las $_total fotos quedaron guardadas en el teléfono.'
                : '${_total - failed} de $_total fotos guardadas. Las demás '
                      'no se pudieron descargar; revisa tu conexión y vuelve a '
                      'intentarlo.',
            key: const Key('downloadResult'),
            textAlign: TextAlign.center,
            style: textStyle(context),
          ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: failed == null ? 'Seguir en segundo plano' : 'Listo',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
