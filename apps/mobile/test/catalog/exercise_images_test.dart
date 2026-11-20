import 'dart:io';

import 'package:anfybio/catalog/exercise_images.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late List<Uri> requested;

  setUp(() {
    root = Directory.systemTemp.createTempSync('imagenes');
    requested = [];
  });
  tearDown(() => root.deleteSync(recursive: true));

  CachedRemoteImageStore store({bool online = true}) => CachedRemoteImageStore(
    directory: () async => root,
    baseUrl: 'https://cdn.example/fotos/',
    fetch: (url) async {
      requested.add(url);
      if (!online) throw const SocketException('sin red');
      return [1, 2, 3];
    },
  );

  test('descarga la foto la primera vez y la guarda', () async {
    final file = await store().image('Press/0.jpg');

    expect(file!.readAsBytesSync(), [1, 2, 3]);
    expect(file.path, '${root.path}/Press/0.jpg');
    expect(
      requested.single.toString(),
      'https://cdn.example/fotos/Press/0.jpg',
    );
  });

  test('después la toma del teléfono, sin volver a descargarla', () async {
    await store().image('Press/0.jpg');
    // Otra instancia, como al volver a abrir la app.
    final again = await store(online: false).image('Press/0.jpg');

    expect(again, isNotNull);
    expect(requested, hasLength(1));
  });

  test('sin internet devuelve nulo y no deja archivos a medias', () async {
    final file = await store(online: false).image('Press/0.jpg');

    expect(file, isNull);
    expect(root.listSync(recursive: true).whereType<File>(), isEmpty);
  });

  test(
    'pedir la misma foto dos veces a la vez la descarga una sola vez',
    () async {
      final images = store();
      await Future.wait([images.image('A/0.jpg'), images.image('A/0.jpg')]);
      expect(requested, hasLength(1));
    },
  );

  test('rechaza rutas que saldrían de su carpeta', () async {
    expect(await store().image('../secreto.jpg'), isNull);
    expect(await store().image('/etc/passwd'), isNull);
    expect(requested, isEmpty);
  });

  test('descargar varias informa el avance y cuántas fallaron', () async {
    final progress = <(int, int)>[];
    var calls = 0;
    final images = CachedRemoteImageStore(
      directory: () async => root,
      baseUrl: 'https://cdn.example/',
      fetch: (url) async {
        calls++;
        if (url.path.contains('B')) throw const SocketException('falla');
        return [9];
      },
    );

    final failed = await images.downloadAll([
      'A/0.jpg',
      'B/0.jpg',
      'C/0.jpg',
    ], onProgress: (done, total) => progress.add((done, total)));

    expect(failed, 1);
    expect(progress, [(1, 3), (2, 3), (3, 3)]);
    expect(calls, 3);
  });

  test('la URL por defecto apunta a una versión fija del catálogo', () {
    expect(catalogCommit, matches(RegExp(r'^[0-9a-f]{40}$')));
  });
}
