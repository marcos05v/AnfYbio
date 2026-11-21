/// Una compra: cuánto entró al inventario, en la unidad del suplemento.
typedef StockPurchase = ({DateTime at, double quantity});

/// Algo que salió del inventario. Una **toma** cuenta para la adherencia; un
/// **ajuste** corrige las existencias (puede ser negativo, si había más de lo
/// que la app creía) y no cuenta como toma.
typedef StockOutflow = ({DateTime at, double amount, bool isAdjustment});

/// Días de registro a partir de los cuales el consumo real es más fiable que
/// la dosis del plan para predecir cuándo se acaba.
const int minDaysForActualRate = 7;

/// Ventana, en días, sobre la que se mide la adherencia.
const int adherenceWindowDays = 30;

/// Estado del inventario de un suplemento en un momento dado.
class InventoryStatus {
  const InventoryStatus({
    required this.stock,
    required this.dailyRate,
    required this.usesActualRate,
    required this.daysLeft,
    required this.runOutDate,
    required this.needsRestock,
    required this.adherence,
    required this.takenToday,
  });

  /// Lo que queda, en la unidad del suplemento. Nunca es negativo.
  final double stock;

  /// Consumo diario con el que se predice: el real si hay historial
  /// suficiente, o la dosis indicada si no.
  final double dailyRate;
  final bool usesActualRate;

  /// Días completos que alcanzan las existencias a ese ritmo.
  final int daysLeft;

  /// Día en que se termina; `null` si ya no queda nada.
  final DateTime? runOutDate;

  /// Quedan tantos días o menos como el aviso configurado.
  final bool needsRestock;

  /// Fracción de días con toma en la ventana (0–1); `null` si aún no hay
  /// ninguna toma registrada.
  final double? adherence;
  final bool takenToday;
}

/// Calcula el estado del inventario. Nada de esto se guarda: sale siempre de
/// las compras y las tomas (ADR-0002, regla 5).
///
/// Las fechas se comparan por día de calendario **local**: quien llama debe
/// pasar [now] y las fechas ya convertidas a hora local.
InventoryStatus inventoryStatus({
  required double dailyDose,
  required int restockLeadDays,
  required Iterable<StockPurchase> purchases,
  required Iterable<StockOutflow> outflows,
  required DateTime now,
}) {
  final today = _dayNumber(now);
  final purchased = purchases.fold(0.0, (sum, p) => sum + p.quantity);
  final consumed = outflows.fold(0.0, (sum, o) => sum + o.amount);
  final stock = purchased > consumed ? purchased - consumed : 0.0;

  // Tomas reales (no ajustes) hasta hoy.
  final intakes = [
    for (final outflow in outflows)
      if (!outflow.isAdjustment && _dayNumber(outflow.at) <= today) outflow,
  ];
  final takenToday = intakes.any((i) => _dayNumber(i.at) == today);

  double? adherence;
  double? actualRate;
  if (intakes.isNotEmpty) {
    final firstDay = intakes.map((i) => _dayNumber(i.at)).reduce(_min);
    // La ventana empieza en la primera toma, sin pasar de 30 días atrás.
    final windowStart = _max(firstDay, today - (adherenceWindowDays - 1));
    final windowDays = today - windowStart + 1;
    final inWindow = intakes.where((i) => _dayNumber(i.at) >= windowStart);
    final daysWithIntake = inWindow.map((i) => _dayNumber(i.at)).toSet().length;
    adherence = daysWithIntake / windowDays;

    if (windowDays >= minDaysForActualRate) {
      final total = inWindow.fold(0.0, (sum, i) => sum + i.amount);
      if (total > 0) actualRate = total / windowDays;
    }
  }

  final dailyRate = actualRate ?? dailyDose;
  final daysLeft = dailyRate > 0 ? (stock / dailyRate).floor() : 0;

  return InventoryStatus(
    stock: stock,
    dailyRate: dailyRate,
    usesActualRate: actualRate != null,
    daysLeft: daysLeft,
    runOutDate: stock > 0
        ? DateTime(now.year, now.month, now.day + daysLeft)
        : null,
    needsRestock: daysLeft <= restockLeadDays,
    adherence: adherence,
    takenToday: takenToday,
  );
}

/// Dosis escrita en la guía del plan ("5 g al día", "2,000 UI") separada en
/// cantidad y unidad, para proponerla al dar de alta el suplemento. `null`
/// si el texto no empieza con una cantidad y una unidad.
({double amount, String unit})? parseDose(String? text) {
  if (text == null) return null;
  final match = RegExp(
    r'^\s*(\d{1,3}(?:[.,]\d{3})+|\d+(?:[.,]\d+)?)\s*([A-Za-zµ]+)',
  ).firstMatch(text);
  if (match == null) return null;

  final number = match.group(1)!;
  // "2,000" o "2.000" son miles; "2,5" o "2.5" son decimales.
  final isThousands = RegExp(r'^\d{1,3}(?:[.,]\d{3})+$').hasMatch(number);
  final amount = double.tryParse(
    isThousands
        ? number.replaceAll(RegExp(r'[.,]'), '')
        : number.replaceAll(',', '.'),
  );
  if (amount == null || amount <= 0) return null;

  final unit = match.group(2)!;
  // "UI" (unidades internacionales) suele escribirse mal como "Ul" o "ui".
  final normalized = RegExp(r'^u[il]$', caseSensitive: false).hasMatch(unit)
      ? 'UI'
      : unit.toLowerCase();
  return (amount: amount, unit: normalized);
}

/// En qué presentación viene un suplemento. De ella depende la unidad con la
/// que se lleva su inventario.
enum SupplementPresentation { pills, powder, other }

/// Unidad con la que se cuentan las pastillas, cápsulas o tabletas.
const String pillsUnit = 'pastillas';

/// Unidad con la que se pesa un polvo.
const String powderUnit = 'g';

/// La presentación que corresponde a una unidad ya guardada. No se almacena
/// aparte: se deduce de la unidad del suplemento.
SupplementPresentation presentationOf(String unitLabel) {
  final unit = unitLabel.trim().toLowerCase();
  const pillWords = ['pastilla', 'capsula', 'cápsula', 'tableta', 'comprimido'];
  if (pillWords.any(unit.startsWith)) return SupplementPresentation.pills;
  if (const ['g', 'gr', 'gramo', 'gramos'].contains(unit)) {
    return SupplementPresentation.powder;
  }
  return SupplementPresentation.other;
}

/// Cuánto se calcula que ya se consumió de un envase empezado: la dosis
/// diaria por cada día transcurrido desde la compra, sin contar hoy y sin
/// pasar de lo que traía el envase.
///
/// Es una estimación para no empezar el inventario en blanco; el usuario
/// puede corregirla después con lo que realmente le queda.
double estimatedConsumed({
  required double dailyDose,
  required double quantity,
  required DateTime purchasedOn,
  required DateTime today,
}) {
  final days = _dayNumber(today) - _dayNumber(purchasedOn);
  if (days <= 0 || dailyDose <= 0) return 0;
  final consumed = dailyDose * days;
  return consumed < quantity ? consumed : quantity;
}

int _dayNumber(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

int _min(int a, int b) => a < b ? a : b;
int _max(int a, int b) => a > b ? a : b;

/// Cómo se da de alta en el inventario un suplemento de la guía del plan:
/// con la dosis en gramos es un polvo y se toma esa cantidad; con mg o UI es
/// la concentración de cada pastilla, y se propone una al día. Sin dosis
/// legible, también una pastilla.
({String unitLabel, double dailyDose}) inventoryFromGuide(String? dose) {
  final parsed = parseDose(dose);
  return parsed?.unit == powderUnit
      ? (unitLabel: powderUnit, dailyDose: parsed!.amount)
      : (unitLabel: pillsUnit, dailyDose: 1);
}
