import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// Columnas comunes a toda tabla con datos del usuario (ADR-0002).
mixin SyncColumns on Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v7())();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
