import 'dart:io';
import 'dart:ui';

import 'package:file_selector/file_selector.dart' as selector;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/export/backup_exporter.dart';
import '../data/export/backup_importer.dart';
import 'providers.dart';

final backupExporterProvider = Provider(
  (ref) => BackupExporter(ref.watch(databaseProvider)),
);

/// Entrega el respaldo al usuario. [origin] es la zona de la pantalla desde
/// la que sale la hoja de compartir (la exige el iPad).
typedef BackupSharer = Future<void> Function(Backup backup, {Rect? origin});

/// En la app abre la hoja de compartir de iOS; las pruebas lo reemplazan.
final backupSharerProvider = Provider<BackupSharer>((ref) => _shareAsFile);

/// Escribe el respaldo en un archivo temporal y abre la hoja de compartir,
/// desde donde se puede guardar en Archivos, iCloud Drive o enviar por AirDrop.
Future<void> _shareAsFile(Backup backup, {Rect? origin}) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/${backup.fileName}');
  await file.writeAsString(backup.json);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'application/json')],
      sharePositionOrigin: origin,
    ),
  );
}

final backupImporterProvider = Provider(
  (ref) => BackupImporter(ref.watch(databaseProvider)),
);

/// Deja elegir un archivo y devuelve su contenido; `null` si se cancela.
typedef BackupPicker = Future<String?> Function();

/// En la app abre el selector de archivos de iOS; las pruebas lo reemplazan.
final backupPickerProvider = Provider<BackupPicker>((ref) => _pickFile);

Future<String?> _pickFile() async {
  final file = await selector.openFile(
    acceptedTypeGroups: const [
      selector.XTypeGroup(
        label: 'Respaldo de AnfYbio',
        extensions: ['json'],
        mimeTypes: ['application/json'], // Android
        uniformTypeIdentifiers: ['public.json'],
      ),
    ],
  );
  return file?.readAsString();
}
