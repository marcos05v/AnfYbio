import 'nutrition.dart';

/// Factor de rendimiento de un lote: cuánto pesa cocido por cada gramo en
/// crudo. El pollo suele rondar 0.7 (pierde agua); el arroz pasa de 2
/// (la absorbe). `null` si los pesos no son positivos.
double? yieldFactor({required double rawG, required double cookedG}) {
  if (rawG <= 0 || cookedG <= 0) return null;
  return cookedG / rawG;
}

/// Gramos cocidos que hay que servir para cumplir una porción que el plan
/// expresa en crudo.
double cookedPortionG({required double rawPortionG, required double factor}) =>
    rawPortionG * factor;

/// Nombre de alimento reducido a lo comparable: minúsculas, sin acentos, sin
/// aclaraciones entre paréntesis y sin espacios repetidos.
String normalizeFood(String name) {
  const accents = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };
  final text = name
      .toLowerCase()
      .replaceAll(RegExp(r'\([^)]*\)'), ' ')
      .split('')
      .map((char) => accents[char] ?? char)
      .join()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return text;
}

/// Si un lote de [batchFood] sirve para un renglón del plan llamado
/// [itemName], que puede traer alternativas ("Pollo o res magra").
///
/// Coinciden cuando el lote es una de las alternativas, o cuando uno de los
/// dos nombres contiene al otro como palabras completas ("pollo" sirve para
/// "pechuga de pollo"; "arroz" no sirve para "arrozal").
bool batchMatchesItem({required String batchFood, required String itemName}) {
  final batch = normalizeFood(batchFood);
  if (batch.isEmpty) return false;
  bool contains(String text, String words) => ' $text '.contains(' $words ');

  return foodOptions(itemName)
      .map(normalizeFood)
      .any(
        (option) =>
            option.isNotEmpty &&
            (contains(option, batch) || contains(batch, option)),
      );
}

/// Cómo servir un renglón del plan que se pesa en crudo, según un lote.
class CookedServing {
  const CookedServing({required this.cookedG, required this.isApproximate});

  /// Gramos cocidos equivalentes a la porción en crudo del plan.
  final double cookedG;

  /// El lote se cocinó con otros ingredientes: el dato es orientativo.
  final bool isApproximate;
}

/// Un lote reducido a lo que necesita el cálculo.
typedef BatchInfo = ({
  String foodName,
  double rawG,
  double cookedG,
  bool withOtherIngredients,
});

/// Los gramos cocidos a servir para un renglón del plan, usando el lote más
/// reciente que le corresponda. [batches] debe venir del más reciente al más
/// antiguo.
///
/// Solo aplica a renglones en gramos que el plan pide **en crudo**; para los
/// demás devuelve `null` (un alimento que ya se pesa cocido no necesita
/// conversión, y uno "sin especificar" no se convierte a ciegas).
CookedServing? cookedServingFor({
  required String itemName,
  required double? amount,
  required FoodUnit? unit,
  required FoodState state,
  required Iterable<BatchInfo> batches,
}) {
  if (amount == null || unit != FoodUnit.gram || state != FoodState.raw) {
    return null;
  }
  for (final batch in batches) {
    if (!batchMatchesItem(batchFood: batch.foodName, itemName: itemName)) {
      continue;
    }
    final factor = yieldFactor(rawG: batch.rawG, cookedG: batch.cookedG);
    if (factor == null) continue;
    return CookedServing(
      cookedG: cookedPortionG(rawPortionG: amount, factor: factor),
      isApproximate: batch.withOtherIngredients,
    );
  }
  return null;
}
