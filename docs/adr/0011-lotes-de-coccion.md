# ADR-0011: Lotes de cocción y conversión de crudo a cocido

- Estado: Aceptado
- Fecha: 2026-11-16

## Contexto

El plan pide las proteínas pesadas en crudo, pero en la práctica se cocinan
varias porciones de una vez y se sirven ya cocidas. Un alimento cambia de peso
al cocinarse (el pollo pierde agua, el arroz la absorbe), y ese cambio depende
de cómo se cocine: no hay un factor fijo que sirva siempre.

## Decisión

El usuario registra cada **lote**: alimento, peso en crudo y peso ya cocido.
De ahí sale el factor de rendimiento (cocido ÷ crudo), que no se guarda sino
que se calcula (ADR-0002, regla 5).

En el plan, cada renglón que cumpla las tres condiciones muestra cuántos
gramos cocidos servir:

1. su cantidad está en gramos;
2. el plan lo pide **en crudo**;
3. existe un lote de ese alimento.

- Se usa **el lote más reciente** del alimento.
- El lote se empareja con el renglón por nombre, comparando sin acentos ni
  mayúsculas y aceptando cualquiera de las alternativas del renglón ("pollo o
  res"). Al registrar un lote, la app sugiere los alimentos que el plan pide
  en crudo, para que los nombres coincidan.
- Un lote marcado **"con otros ingredientes"** da un dato aproximado, y así se
  muestra: su peso cocido incluye la salsa o las verduras.
- Un renglón "sin especificar" no se convierte: aplicar un factor sin saber si
  la cantidad es en crudo daría una porción equivocada.

## Alternativas consideradas

**Tabla de factores típicos por alimento.** No exigiría pesar nada. Se
descartó porque el rendimiento real varía mucho con el método y el punto de
cocción, y la app daría un número con apariencia de exacto que no lo es.

**Enlazar cada lote a un renglón del plan con una llave.** Evita emparejar por
nombre. Se descartó porque un mismo lote de pollo sirve para varias comidas y
para los dos menús, y el plan se reemplaza con frecuencia: los lotes dejarían
de corresponder al importar uno nuevo.

**Promediar los últimos lotes.** Suaviza errores de pesaje. Se descartó porque
lo que está en el refrigerador es el último lote, y su factor es el que
aplica.

## Consecuencias

- La conversión depende de que el usuario pese dos veces lo que cocina.
- El emparejamiento por nombre puede fallar si el lote se nombra distinto al
  plan; entonces simplemente no aparece la conversión, sin dar un dato falso.
- Un lote antiguo sigue aplicando hasta que se registre otro o se borre; la
  app no los caduca.
- Los lotes entran en el respaldo. Es la versión 4 del esquema, con su prueba
  de migración.
