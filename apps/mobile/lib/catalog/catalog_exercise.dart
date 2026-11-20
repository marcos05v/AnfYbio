/// Un ejercicio del catálogo (free-exercise-db, dominio público), con su
/// traducción al español.
class CatalogExercise {
  const CatalogExercise({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.level,
    required this.category,
    required this.primaryMuscles,
    required this.secondaryMuscles,
    required this.instructions,
    required this.images,
    this.force,
    this.mechanic,
    this.equipment,
  });

  /// Identificador estable del catálogo: "Barbell_Bench_Press_-_Medium_Grip".
  final String id;

  /// Nombre en español.
  final String name;

  /// Nombre original en inglés, también útil para buscar.
  final String nameEn;
  final String level;
  final String category;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;

  /// Pasos en español.
  final List<String> instructions;

  /// Rutas relativas de las fotos (posición inicial y final).
  final List<String> images;

  /// Opcionales: el catálogo los deja nulos en algunos ejercicios.
  final String? force;
  final String? mechanic;
  final String? equipment;

  /// Lee una entrada del archivo incluido en la app: los campos originales
  /// del catálogo más su traducción en `es`.
  factory CatalogExercise.fromJson(Map<String, dynamic> json) {
    final es = json['es'] as Map<String, dynamic>;
    List<String> strings(Object? list) => [
      for (final item in list! as List) item as String,
    ];
    return CatalogExercise(
      id: json['id'] as String,
      name: es['name'] as String,
      nameEn: json['name'] as String,
      level: json['level'] as String,
      category: json['category'] as String,
      primaryMuscles: strings(json['primaryMuscles']),
      secondaryMuscles: strings(json['secondaryMuscles']),
      instructions: strings(es['instructions']),
      images: strings(json['images']),
      force: json['force'] as String?,
      mechanic: json['mechanic'] as String?,
      equipment: json['equipment'] as String?,
    );
  }
}

/// Nombres en español de los valores fijos del catálogo.
const muscleLabels = {
  'abdominals': 'Abdomen',
  'abductors': 'Abductores',
  'adductors': 'Aductores',
  'biceps': 'Bíceps',
  'calves': 'Pantorrillas',
  'chest': 'Pecho',
  'forearms': 'Antebrazos',
  'glutes': 'Glúteos',
  'hamstrings': 'Isquiotibiales',
  'lats': 'Dorsales',
  'lower back': 'Zona lumbar',
  'middle back': 'Espalda media',
  'neck': 'Cuello',
  'quadriceps': 'Cuádriceps',
  'shoulders': 'Hombros',
  'traps': 'Trapecio',
  'triceps': 'Tríceps',
};

const equipmentLabels = {
  'bands': 'Banda elástica',
  'barbell': 'Barra',
  'body only': 'Peso corporal',
  'cable': 'Polea',
  'dumbbell': 'Mancuerna',
  'e-z curl bar': 'Barra Z',
  'exercise ball': 'Pelota de ejercicio',
  'foam roll': 'Rodillo de espuma',
  'kettlebells': 'Pesa rusa',
  'machine': 'Máquina',
  'medicine ball': 'Balón medicinal',
  'other': 'Otro',
};

const levelLabels = {
  'beginner': 'Principiante',
  'intermediate': 'Intermedio',
  'expert': 'Avanzado',
};

const categoryLabels = {
  'cardio': 'Cardio',
  'olympic weightlifting': 'Halterofilia',
  'plyometrics': 'Pliometría',
  'powerlifting': 'Powerlifting',
  'strength': 'Fuerza',
  'stretching': 'Estiramiento',
  'strongman': 'Strongman',
};

const mechanicLabels = {
  'compound': 'Multiarticular',
  'isolation': 'Aislamiento',
};

const forceLabels = {'pull': 'Tirón', 'push': 'Empuje', 'static': 'Estático'};
