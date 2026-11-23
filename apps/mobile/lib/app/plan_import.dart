import 'package:file_selector/file_selector.dart' as selector;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Un PDF elegido por el usuario, ya convertido en texto.
typedef PickedPdf = ({String fileName, String text});

/// Deja elegir un PDF y devuelve su texto; `null` si se cancela.
typedef PdfTextPicker = Future<PickedPdf?> Function();

/// En la app abre el selector de archivos de iOS y extrae el texto con el
/// lector de PDF del sistema; las pruebas lo reemplazan.
final pdfTextPickerProvider = Provider<PdfTextPicker>((ref) => _pickPdf);

const _channel = MethodChannel('anfybio/pdf_text');

Future<PickedPdf?> _pickPdf() async {
  final file = await selector.openFile(
    acceptedTypeGroups: const [
      selector.XTypeGroup(
        label: 'PDF',
        extensions: ['pdf'],
        mimeTypes: ['application/pdf'], // Android
        uniformTypeIdentifiers: ['com.adobe.pdf'],
      ),
    ],
  );
  if (file == null) return null;
  final text = await _channel.invokeMethod<String>('extractText', file.path);
  return (fileName: file.name, text: text ?? '');
}
