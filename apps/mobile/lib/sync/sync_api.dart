import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Puerto en el que escucha la API en la Mac (ADR-0019).
const defaultServerPort = 4310;

/// Algo salió mal al hablar con el servidor. [message] se muestra tal cual.
class SyncException implements Exception {
  const SyncException(this.message, {this.sessionExpired = false});

  final String message;

  /// El servidor rechazó el token: hay que volver a iniciar sesión.
  final bool sessionExpired;

  @override
  String toString() => message;
}

/// La dirección del servidor a partir de lo que escribe el usuario:
/// "mi-mac.local" → http://mi-mac.local:4310. Si trae esquema o puerto, se
/// respetan.
Uri serverUri(String input) {
  var text = input.trim();
  if (text.isEmpty) {
    throw const SyncException('Escribe la dirección del servidor.');
  }
  if (!text.contains('://')) text = 'http://$text';
  final uri = Uri.tryParse(text);
  if (uri == null || uri.host.isEmpty) {
    throw const SyncException('La dirección del servidor no es válida.');
  }
  return uri.hasPort ? uri : uri.replace(port: defaultServerPort);
}

/// Una sesión iniciada en el servidor (ADR-0017).
class ServerSession {
  const ServerSession({
    required this.token,
    required this.userId,
    required this.username,
  });

  final String token;
  final String userId;
  final String username;
}

class PushResult {
  const PushResult({
    required this.applied,
    required this.skipped,
    required this.rejected,
  });

  final int applied;
  final int skipped;
  final int rejected;
}

class PulledRow {
  const PulledRow(this.table, this.data);

  final String table;
  final Map<String, dynamic> data;
}

class PullPage {
  const PullPage({
    required this.rows,
    required this.next,
    required this.hasMore,
  });

  final List<PulledRow> rows;
  final int next;
  final bool hasMore;
}

/// Las llamadas a la API de sincronización.
class SyncApi {
  SyncApi(this.baseUri, {http.Client? client})
    : _client = client ?? http.Client();

  final Uri baseUri;
  final http.Client _client;

  static const _timeout = Duration(seconds: 15);

  /// Comprueba que la dirección es un servidor de AnfYbio y no otro programa
  /// escuchando en el mismo puerto.
  Future<void> checkHealth() async {
    final body = await _send('GET', '/health');
    if (body is! Map || body['service'] != 'anfybio') {
      throw const SyncException(
        'En esa dirección responde otro programa, no el servidor de AnfYbio.',
      );
    }
  }

  Future<ServerSession> register({
    required String userId,
    required String username,
    required String password,
  }) async => _session(
    await _send(
      'POST',
      '/auth/register',
      body: {'userId': userId, 'username': username, 'password': password},
    ),
  );

  Future<ServerSession> login({
    required String username,
    required String password,
  }) async => _session(
    await _send(
      'POST',
      '/auth/login',
      body: {'username': username, 'password': password},
    ),
  );

  Future<PushResult> push(
    String token,
    List<({String table, Map<String, dynamic> data})> rows,
  ) async {
    final body = await _send(
      'POST',
      '/sync/push',
      token: token,
      body: {
        'rows': [
          for (final row in rows) {'table': row.table, 'data': row.data},
        ],
      },
    );
    return PushResult(
      applied: body['applied'] as int,
      skipped: body['skipped'] as int,
      rejected: (body['rejected'] as List).length,
    );
  }

  Future<PullPage> pull(String token, {required int since, int? limit}) async {
    final body = await _send(
      'GET',
      '/sync/pull',
      token: token,
      query: {'since': '$since', 'limit': ?limit?.toString()},
    );
    return PullPage(
      rows: [
        for (final row in body['rows'] as List)
          PulledRow(
            row['table'] as String,
            (row['data'] as Map).cast<String, dynamic>(),
          ),
      ],
      next: body['next'] as int,
      hasMore: body['hasMore'] as bool,
    );
  }

  ServerSession _session(dynamic body) => ServerSession(
    token: body['token'] as String,
    userId: body['userId'] as String,
    username: body['username'] as String,
  );

  Future<dynamic> _send(
    String method,
    String path, {
    String? token,
    Map<String, Object?>? body,
    Map<String, String>? query,
  }) async {
    final uri = baseUri.replace(path: path, queryParameters: query);
    final request = http.Request(method, uri)
      ..headers['accept'] = 'application/json';
    if (token != null) request.headers['authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(_timeout),
      );
    } on TimeoutException {
      throw const SyncException(
        'El servidor no respondió. Revisa que la Mac esté encendida, con el '
        'servidor corriendo y en el mismo Wi-Fi.',
      );
    } on SocketException {
      throw const SyncException(
        'No se encontró el servidor. Revisa la dirección y que el teléfono '
        'esté en el mismo Wi-Fi que la Mac.',
      );
    } on http.ClientException {
      throw const SyncException(
        'No se encontró el servidor. Revisa la dirección y que el teléfono '
        'esté en el mismo Wi-Fi que la Mac.',
      );
    }

    final decoded = _decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    final message = decoded is Map ? decoded['message'] : null;
    throw switch (response.statusCode) {
      401 when token != null => const SyncException(
        'La sesión venció. Vuelve a iniciar sesión.',
        sessionExpired: true,
      ),
      401 => const SyncException('Usuario o contraseña incorrectos.'),
      409 => const SyncException('Ese usuario ya existe. Elige otro.'),
      400 => SyncException(
        message is List
            ? message.join('\n')
            : '${message ?? 'El servidor rechazó los datos.'}',
      ),
      404 => const SyncException(
        'En esa dirección responde otro programa, no el servidor de AnfYbio.',
      ),
      _ => SyncException('Error del servidor (${response.statusCode}).'),
    };
  }

  Object? _decode(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }
}
