import 'package:drift/drift.dart';

import 'sync_columns.dart';

class Users extends Table with SyncColumns {
  TextColumn get displayName => text().withLength(min: 1, max: 50)();
}
