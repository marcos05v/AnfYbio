import 'package:anfybio/domain/supplement_inventory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 11, 16, 9);
  DateTime daysAgo(int days) => today.subtract(Duration(days: days));

  StockPurchase purchase(double quantity, {int ago = 30}) =>
      (at: daysAgo(ago), quantity: quantity);
  StockOutflow intake(int ago, {double amount = 5}) =>
      (at: daysAgo(ago), amount: amount, isAdjustment: false);
  StockOutflow adjustment(double amount, {int ago = 0}) =>
      (at: daysAgo(ago), amount: amount, isAdjustment: true);

  InventoryStatus status({
    double dailyDose = 5,
    int restockLeadDays = 7,
    List<StockPurchase> purchases = const [],
    List<StockOutflow> outflows = const [],
  }) => inventoryStatus(
    dailyDose: dailyDose,
    restockLeadDays: restockLeadDays,
    purchases: purchases,
    outflows: outflows,
    now: today,
  );

  group('existencias', () {
    test('compras menos tomas', () {
      final result = status(
        purchases: [purchase(300)],
        outflows: [intake(2), intake(1), intake(0)],
      );
      expect(result.stock, 285);
    });

    test('suma varias compras', () {
      expect(status(purchases: [purchase(300), purchase(150)]).stock, 450);
    });

    test('nunca son negativas, aunque se registre más de lo comprado', () {
      final result = status(
        purchases: [purchase(10)],
        outflows: [intake(1, amount: 30)],
      );
      expect(result.stock, 0);
      expect(result.runOutDate, isNull);
      expect(result.needsRestock, isTrue);
    });

    test('un ajuste positivo descuenta lo que se tomó sin registrar', () {
      final result = status(
        purchases: [purchase(300)],
        outflows: [adjustment(50)],
      );
      expect(result.stock, 250);
    });

    test('un ajuste negativo devuelve existencias', () {
      final result = status(
        purchases: [purchase(100)],
        outflows: [intake(1, amount: 40), adjustment(-20)],
      );
      expect(result.stock, 80);
    });

    test('sin compras no hay nada', () {
      final result = status();
      expect((result.stock, result.daysLeft), (0, 0));
      expect(result.adherence, isNull);
    });
  });

  group('cuándo se acaba', () {
    test('sin historial usa la dosis indicada', () {
      final result = status(purchases: [purchase(300)]);

      expect((result.dailyRate, result.usesActualRate), (5, false));
      expect(result.daysLeft, 60);
      expect(result.runOutDate, DateTime(2027, 1, 15));
    });

    test('solo cuenta días completos', () {
      final result = status(purchases: [purchase(48)]); // 9.6 días
      expect(result.daysLeft, 9);
    });

    test('con pocos días de registro aún no usa el consumo real', () {
      // 3 días de registro, tomando la mitad de la dosis.
      final result = status(
        purchases: [purchase(300)],
        outflows: [for (var d = 0; d < 3; d++) intake(d, amount: 2.5)],
      );
      expect(result.usesActualRate, isFalse);
    });

    test('con una semana de registro predice con el consumo real', () {
      // 10 días de registro, 5 tomas de 5 → 25 / 10 = 2.5 al día.
      final result = status(
        purchases: [purchase(100)],
        outflows: [
          for (final d in [9, 7, 5, 3, 1]) intake(d),
        ],
      );

      expect(result.usesActualRate, isTrue);
      expect(result.dailyRate, 2.5);
      expect(result.stock, 75);
      expect(result.daysLeft, 30); // al ritmo real dura el doble
    });

    test('los ajustes no cuentan como consumo real', () {
      final result = status(
        purchases: [purchase(500)],
        outflows: [
          for (var d = 0; d < 10; d++) intake(d),
          adjustment(100, ago: 2),
        ],
      );
      expect(result.dailyRate, 5);
    });
  });

  group('aviso de reabastecimiento', () {
    test('avisa cuando quedan los días configurados o menos', () {
      expect(status(purchases: [purchase(35)]).needsRestock, isTrue); // 7 días
      expect(status(purchases: [purchase(40)]).needsRestock, isFalse); // 8
    });

    test('la anticipación es configurable', () {
      final result = status(purchases: [purchase(70)], restockLeadDays: 14);
      expect(result.needsRestock, isTrue); // 14 días
    });
  });

  group('adherencia', () {
    test('sin tomas registradas no hay dato', () {
      expect(status(purchases: [purchase(300)]).adherence, isNull);
    });

    test('días con toma entre días transcurridos desde la primera', () {
      // Primera toma hace 9 días → 10 días; tomó 5.
      final result = status(
        purchases: [purchase(300)],
        outflows: [
          for (final d in [9, 7, 5, 3, 1]) intake(d),
        ],
      );
      expect(result.adherence, 0.5);
    });

    test('dos tomas el mismo día cuentan como un día', () {
      final result = status(
        purchases: [purchase(300)],
        outflows: [intake(1), intake(1), intake(0)],
      );
      expect(result.adherence, 1);
    });

    test('solo mira los últimos 30 días', () {
      final result = status(
        purchases: [purchase(1000)],
        outflows: [
          for (var d = 60; d >= 30; d--) intake(d), // fuera de la ventana
          for (var d = 14; d >= 0; d--) intake(d), // 15 de los últimos 30
        ],
      );
      expect(result.adherence, 0.5);
    });

    test('los ajustes no cuentan como toma', () {
      final result = status(
        purchases: [purchase(300)],
        outflows: [intake(1), adjustment(20)],
      );
      expect(result.takenToday, isFalse);
      expect(result.adherence, 0.5); // 1 día con toma de 2 transcurridos
    });

    test('sabe si ya se tomó hoy, sin importar la hora', () {
      final late = (
        at: DateTime(2026, 11, 16, 23, 30),
        amount: 5.0,
        isAdjustment: false,
      );
      expect(
        status(purchases: [purchase(300)], outflows: [late]).takenToday,
        isTrue,
      );
      expect(
        status(purchases: [purchase(300)], outflows: [intake(1)]).takenToday,
        isFalse,
      );
    });
  });

  group('leer la dosis de la guía', () {
    test('cantidad y unidad', () {
      expect(parseDose('5 g al día'), (amount: 5, unit: 'g'));
      expect(parseDose('200 mg'), (amount: 200, unit: 'mg'));
      expect(parseDose('1 g de EPA/DHA combinados al día.'), (
        amount: 1,
        unit: 'g',
      ));
    });

    test('miles con coma o punto', () {
      expect(parseDose('2,000 UI'), (amount: 2000, unit: 'UI'));
      expect(parseDose('10.000 UI'), (amount: 10000, unit: 'UI'));
    });

    test('decimales con coma o punto', () {
      expect(parseDose('2,5 g'), (amount: 2.5, unit: 'g'));
      expect(parseDose('0.5 mg'), (amount: 0.5, unit: 'mg'));
    });

    test('corrige "Ul" por "UI"', () {
      expect(parseDose('2,000 Ul'), (amount: 2000, unit: 'UI'));
    });

    test('lo que no empieza con cantidad y unidad no se interpreta', () {
      expect(parseDose(null), isNull);
      expect(parseDose(''), isNull);
      expect(parseDose('Una cápsula'), isNull);
      expect(parseDose('500'), isNull);
    });
  });
}
