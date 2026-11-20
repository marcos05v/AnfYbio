"""Arma assets/catalog/exercises.json: el catálogo de free-exercise-db en una
versión fija, con su traducción al español (ADR-0015).

Uso, desde apps/mobile:
    python3 tool/catalog/build_catalog.py [ruta/a/exercises.json]

Sin ruta, descarga el archivo de la versión fijada en CATALOG_COMMIT (la
misma que usa la app para las fotos). Falla si alguna traducción no cuadra
con su ejercicio.
"""
import json
import pathlib
import sys
import urllib.request

CATALOG_COMMIT = "f00c92c7dcf1216a928a52c3706c7ce8e2f71ed5"
SOURCE = (
    "https://raw.githubusercontent.com/yuhonas/free-exercise-db/"
    f"{CATALOG_COMMIT}/dist/exercises.json"
)
HERE = pathlib.Path(__file__).parent
OUTPUT = HERE.parent.parent / "assets" / "catalog" / "exercises.json"


def main() -> None:
    if len(sys.argv) > 1:
        source = json.loads(pathlib.Path(sys.argv[1]).read_text("utf-8"))
    else:
        with urllib.request.urlopen(SOURCE, timeout=60) as response:
            source = json.loads(response.read().decode("utf-8"))
    translations = json.loads((HERE / "translations_es.json").read_text("utf-8"))

    errors = []
    catalog = []
    for exercise in sorted(source, key=lambda e: e["id"]):
        es = translations.get(exercise["id"])
        if es is None:
            errors.append(f"sin traducción: {exercise['id']}")
            continue
        if len(es["instructions"]) != len(exercise["instructions"]):
            errors.append(f"pasos distintos: {exercise['id']}")
        if not es["name"].strip():
            errors.append(f"nombre vacío: {exercise['id']}")
        catalog.append({**exercise, "es": es})
    extra = set(translations) - {e["id"] for e in source}
    errors += [f"traducción sin ejercicio: {i}" for i in sorted(extra)]

    if errors:
        print("\n".join(errors), file=sys.stderr)
        sys.exit(1)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(
        json.dumps(catalog, ensure_ascii=False, separators=(",", ":")), "utf-8"
    )
    print(f"{len(catalog)} ejercicios → {OUTPUT} ({OUTPUT.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
