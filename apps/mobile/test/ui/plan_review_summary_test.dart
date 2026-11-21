import 'package:anfybio/ui/plan_review_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sin suplementos en el plan lo dice', () {
    expect(
      supplementImportSummary((added: const [], existing: const [])),
      'No se encontraron suplementos en el plan.',
    );
  });

  test('dice cuáles se agregaron y cuáles ya estaban', () {
    final text = supplementImportSummary((
      added: const ['Omega 3', 'Zinc'],
      existing: const ['Creatina'],
    ));
    expect(text, startsWith('Se agregaron 2 suplementos: Omega 3, Zinc.'));
    expect(text, contains('Creatina ya estaba en tu inventario.'));
    expect(text, contains('anota cuánto tienes'));
  });

  test('uno solo, en singular', () {
    expect(
      supplementImportSummary((added: const ['Zinc'], existing: const [])),
      startsWith('Se agregó Zinc a tus suplementos.'),
    );
  });
}
