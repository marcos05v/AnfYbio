import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Un servidor de AnfYbio en memoria con las mismas reglas que la API real
/// (apps/api): cuentas, gana el cambio más reciente, número de secuencia y
/// cada quien solo toca lo suyo. Permite probar dos teléfonos sin red.
class FakeSyncServer {
  final _accounts = <String, ({String userId, String password})>{};
  final _tokens = <String, String>{}; // token → userId
  final _rows = <String, _Row>{}; // "tabla/id" → fila
  var _seq = 0;

  /// Para simular un token vencido.
  void expireTokens() => _tokens.clear();

  /// Para simular otro programa escuchando en el puerto.
  bool impostor = false;

  /// Filas guardadas de una cuenta, por tabla.
  Map<String, List<Map<String, dynamic>>> rowsOf(String userId) {
    final result = <String, List<Map<String, dynamic>>>{};
    for (final row in _rows.values.where((r) => r.userId == userId)) {
      result.putIfAbsent(row.table, () => []).add(row.data);
    }
    return result;
  }

  late final client = MockClient((request) async {
    if (impostor) return http.Response('<html>404</html>', 404);
    final path = request.url.path;
    if (path == '/health') return _json({'status': 'ok', 'service': 'anfybio'});
    if (path == '/auth/register') return _register(_body(request));
    if (path == '/auth/login') return _login(_body(request));

    final token = request.headers['authorization']?.replaceFirst('Bearer ', '');
    final userId = _tokens[token];
    if (userId == null) return _json({'message': 'Falta iniciar sesión'}, 401);
    if (path == '/sync/push') return _push(userId, _body(request));
    if (path == '/sync/pull') {
      final since = int.parse(request.url.queryParameters['since'] ?? '0');
      final limit = int.parse(request.url.queryParameters['limit'] ?? '500');
      return _pull(userId, since, limit);
    }
    return _json({'message': 'No existe'}, 404);
  });

  http.Response _register(Map<String, dynamic> body) {
    final username = (body['username'] as String).toLowerCase();
    final userId = body['userId'] as String;
    if (_accounts.containsKey(username) ||
        _accounts.values.any((a) => a.userId == userId)) {
      return _json({'message': 'Ya existe'}, 409);
    }
    _accounts[username] = (
      userId: userId,
      password: body['password'] as String,
    );
    return _json(_session(username, userId), 201);
  }

  http.Response _login(Map<String, dynamic> body) {
    final username = (body['username'] as String).toLowerCase();
    final account = _accounts[username];
    if (account == null || account.password != body['password']) {
      return _json({'message': 'Usuario o contraseña incorrectos'}, 401);
    }
    return _json(_session(username, account.userId));
  }

  Map<String, dynamic> _session(String username, String userId) {
    final token = 'token-${_tokens.length + 1}-$username';
    _tokens[token] = userId;
    return {'token': token, 'userId': userId, 'username': username};
  }

  http.Response _push(String userId, Map<String, dynamic> body) {
    var applied = 0;
    var skipped = 0;
    final rejected = <Map<String, Object?>>[];
    for (final row in (body['rows'] as List).cast<Map<String, dynamic>>()) {
      final table = row['table'] as String;
      final data = (row['data'] as Map).cast<String, dynamic>();
      final owner = table == 'users' ? data['id'] : data['userId'];
      final updatedAt = data['updatedAt'] as String;
      if (owner != userId || !updatedAt.endsWith('Z')) {
        rejected.add({'table': table, 'id': data['id'], 'reason': 'no'});
        continue;
      }
      final key = '$table/${data['id']}';
      final existing = _rows[key];
      if (existing != null &&
          (existing.userId != userId ||
              !DateTime.parse(updatedAt).isAfter(existing.updatedAt))) {
        skipped++;
        continue;
      }
      _rows[key] = _Row(table, userId, DateTime.parse(updatedAt), ++_seq, data);
      applied++;
    }
    return _json({
      'applied': applied,
      'skipped': skipped,
      'rejected': rejected,
    });
  }

  http.Response _pull(String userId, int since, int limit) {
    final found =
        _rows.values.where((r) => r.userId == userId && r.seq > since).toList()
          ..sort((a, b) => a.seq.compareTo(b.seq));
    final page = found.take(limit).toList();
    return _json({
      'rows': [
        for (final row in page) {'table': row.table, 'data': row.data},
      ],
      'next': page.isEmpty ? since : page.last.seq,
      'hasMore': found.length > limit,
    });
  }

  Map<String, dynamic> _body(http.Request request) =>
      jsonDecode(request.body) as Map<String, dynamic>;

  http.Response _json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

class _Row {
  _Row(this.table, this.userId, this.updatedAt, this.seq, this.data);

  final String table;
  final String userId;
  final DateTime updatedAt;
  final int seq;
  final Map<String, dynamic> data;
}
