import 'package:drift/drift.dart';

import '../database.dart';

/// Usuario local del dispositivo.
///
/// En el teléfono hay un solo usuario; la tabla existe para que los datos ya
/// lleven dueño cuando llegue la sincronización (ADR-0002).
class UserRepository {
  UserRepository(this._db);

  final AppDatabase _db;

  /// El usuario del dispositivo, o `null` si aún no se ha creado.
  Stream<User?> watchCurrentUser() {
    return (_db.select(_db.users)
          ..where((u) => u.deletedAt.isNull())
          ..orderBy([(u) => OrderingTerm.asc(u.createdAt)])
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<User> createUser(String displayName) {
    final name = displayName.trim();
    if (name.isEmpty) throw ArgumentError('El nombre no puede estar vacío.');
    return _db
        .into(_db.users)
        .insertReturning(UsersCompanion.insert(displayName: name));
  }
}
