import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/catalog.dart';
import 'theme.dart';

/// Miniatura cuadrada con la primera foto de un ejercicio, para listas.
/// Sin internet (o sin foto) muestra un ícono en su lugar.
class ExerciseThumbnail extends ConsumerStatefulWidget {
  const ExerciseThumbnail({super.key, required this.images, this.size = 52});

  final List<String> images;
  final double size;

  @override
  ConsumerState<ExerciseThumbnail> createState() => _ExerciseThumbnailState();
}

class _ExerciseThumbnailState extends ConsumerState<ExerciseThumbnail> {
  late final Future<File?> _file = widget.images.isEmpty
      ? Future.value()
      : ref.read(exerciseImageStoreProvider).image(widget.images.first);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox.square(
        dimension: widget.size,
        child: FutureBuilder<File?>(
          future: _file,
          builder: (context, snapshot) {
            final file = snapshot.data;
            if (file == null) {
              return ColoredBox(
                color: resolveColor(context, CupertinoColors.systemFill),
                child: Icon(
                  CupertinoIcons.photo,
                  size: widget.size * 0.4,
                  color: resolveColor(context, CupertinoColors.tertiaryLabel),
                ),
              );
            }
            return ColoredBox(
              // Las fotos del catálogo tienen fondo blanco.
              color: CupertinoColors.white,
              child: Image.file(file, fit: BoxFit.cover),
            );
          },
        ),
      ),
    );
  }
}

/// Las dos fotos de un ejercicio (posición inicial y final), alternándose
/// como una animación simple.
class ExerciseImagesView extends ConsumerStatefulWidget {
  const ExerciseImagesView({
    super.key,
    required this.images,
    this.height = 240,
  });

  final List<String> images;
  final double height;

  @override
  ConsumerState<ExerciseImagesView> createState() => _ExerciseImagesViewState();
}

class _ExerciseImagesViewState extends ConsumerState<ExerciseImagesView> {
  late Future<List<File?>> _files;
  Timer? _timer;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final store = ref.read(exerciseImageStoreProvider);
    _files = Future.wait(widget.images.map(store.image));
    _files.then((files) {
      if (!mounted || files.whereType<File>().length < 2) return;
      // Cada 1.2 s cambia de posición, como un GIF.
      _timer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
        if (mounted) setState(() => _current = 1 - _current);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final background = resolveColor(context, cardColor);

    Widget placeholder(Widget child) => Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(cardRadius),
      ),
      alignment: Alignment.center,
      child: child,
    );

    if (widget.images.isEmpty) {
      return placeholder(
        Text(
          'Este ejercicio no tiene fotos.',
          style: textStyle(context, color: CupertinoColors.secondaryLabel),
        ),
      );
    }

    return FutureBuilder<List<File?>>(
      future: _files,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return placeholder(const CupertinoActivityIndicator());
        }
        final files = snapshot.data!.whereType<File>().toList();
        if (files.isEmpty) {
          return placeholder(
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.wifi_slash,
                    color: resolveColor(context, CupertinoColors.tertiaryLabel),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Las fotos se descargan la primera vez que ves el '
                    'ejercicio con internet.',
                    textAlign: TextAlign.center,
                    style: textStyle(
                      context,
                      size: 14,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                  CupertinoButton(
                    onPressed: () => setState(_load),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }
        final file = files[_current % files.length];
        return ClipRRect(
          borderRadius: BorderRadius.circular(cardRadius),
          child: Container(
            height: widget.height,
            // Las fotos del catálogo tienen fondo blanco.
            color: CupertinoColors.white,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Image.file(
                file,
                key: ValueKey(file.path),
                fit: BoxFit.contain,
                width: double.infinity,
                height: widget.height,
              ),
            ),
          ),
        );
      },
    );
  }
}
