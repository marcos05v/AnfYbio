import 'dart:io';

/// Las fotos de los ejercicios del catálogo (ADR-0015, opción C): no vienen
/// dentro de la app, se descargan la primera vez que se ven y se guardan en
/// el teléfono.
abstract class ExerciseImageStore {
  /// El archivo local de la foto, descargándola si aún no está. `null` si no
  /// se pudo obtener (por ejemplo, sin internet).
  Future<File?> image(String relativePath);

  /// Descarga las fotos que falten. [onProgress] recibe cuántas van de
  /// cuántas. Devuelve cuántas no se pudieron descargar.
  Future<int> downloadAll(
    List<String> relativePaths, {
    void Function(int done, int total)? onProgress,
  });
}

/// No tiene fotos. Es el valor por defecto, para que las pruebas no usen la
/// red; `main` lo reemplaza por [CachedRemoteImageStore].
class NoImageStore implements ExerciseImageStore {
  const NoImageStore();

  @override
  Future<File?> image(String relativePath) async => null;

  @override
  Future<int> downloadAll(
    List<String> relativePaths, {
    void Function(int done, int total)? onProgress,
  }) async => relativePaths.length;
}

/// Versión exacta del repositorio del catálogo de la que salen datos y
/// fotos. Fijarla garantiza que las fotos nunca cambien ni desaparezcan.
const catalogCommit = 'f00c92c7dcf1216a928a52c3706c7ce8e2f71ed5';

/// Descarga desde jsDelivr (CDN gratuita para proyectos de código abierto)
/// y guarda cada foto en una carpeta propia de la app.
class CachedRemoteImageStore implements ExerciseImageStore {
  CachedRemoteImageStore({
    required this.directory,
    Future<List<int>> Function(Uri url)? fetch,
    String? baseUrl,
  }) : _fetch = fetch ?? _httpGet,
       _baseUrl =
           baseUrl ??
           'https://cdn.jsdelivr.net/gh/yuhonas/free-exercise-db@$catalogCommit/exercises/';

  /// Carpeta donde se guardan las fotos descargadas.
  final Future<Directory> Function() directory;
  final Future<List<int>> Function(Uri url) _fetch;
  final String _baseUrl;

  /// Descargas en curso, para no pedir dos veces la misma foto.
  final _pending = <String, Future<File?>>{};

  @override
  Future<File?> image(String relativePath) {
    // El bloque no debe devolver nada: `remove` devolvería esta misma
    // descarga y whenComplete se quedaría esperándola para siempre.
    return _pending[relativePath] ??= _load(relativePath).whenComplete(() {
      _pending.remove(relativePath);
    });
  }

  Future<File?> _load(String relativePath) async {
    // Las rutas vienen del catálogo, pero se valida que no salgan de la
    // carpeta.
    if (relativePath.contains('..') || relativePath.startsWith('/')) {
      return null;
    }
    final root = await directory();
    final file = File('${root.path}/$relativePath');
    if (file.existsSync()) return file;
    try {
      final bytes = await _fetch(Uri.parse('$_baseUrl$relativePath'));
      if (bytes.isEmpty) return null;
      await file.parent.create(recursive: true);
      // Se escribe aparte y luego se renombra: una descarga cortada nunca
      // deja una foto a medias.
      final partial = File('${file.path}.part');
      await partial.writeAsBytes(bytes, flush: true);
      await partial.rename(file.path);
      return file;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<int> downloadAll(
    List<String> relativePaths, {
    void Function(int done, int total)? onProgress,
  }) async {
    var failed = 0;
    for (final (index, path) in relativePaths.indexed) {
      if (await image(path) == null) failed++;
      onProgress?.call(index + 1, relativePaths.length);
    }
    return failed;
  }

  static Future<List<int>> _httpGet(Uri url) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(url);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}', uri: url);
      }
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
      }
      return bytes;
    } finally {
      client.close();
    }
  }
}
