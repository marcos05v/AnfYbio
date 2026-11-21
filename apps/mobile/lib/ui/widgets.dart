import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;

import '../data/tables/sessions.dart';
import 'formatting.dart';
import 'theme.dart';

/// Botón principal: ancho completo, 52 pt de alto y esquinas redondeadas.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = resolveColor(context, onAccentColor);
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        color: accentColor,
        borderRadius: BorderRadius.circular(cardRadius),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: foreground),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: textStyle(
                context,
                weight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón secundario: misma forma que el principal, sin color de acento.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        color: cardColor,
        borderRadius: BorderRadius.circular(cardRadius),
        onPressed: onPressed,
        child: Text(label, style: textStyle(context, weight: FontWeight.w600)),
      ),
    );
  }
}

/// Botón contorneado con icono "+": para agregar un elemento a una lista
/// sin competir con el botón principal de la pantalla.
class OutlineAddButton extends StatelessWidget {
  const OutlineAddButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = resolveColor(context, accentColor);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          border: Border.all(color: accent, width: 1.5),
          borderRadius: BorderRadius.circular(cardRadius),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.plus_circle_fill, size: 20, color: accent),
            const SizedBox(width: 8),
            Text(
              label,
              style: textStyle(context, weight: FontWeight.w600, color: accent),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pie de un formulario: guardar y, si se está editando, borrar.
///
/// Borrar es un botón cuadrado con un bote de basura, a la izquierda del
/// principal: se distingue por forma y color, y pide confirmación.
class FormActions extends StatelessWidget {
  const FormActions({
    super.key,
    required this.saveLabel,
    required this.onSave,
    this.deleteLabel,
    this.onDelete,
  });

  final String saveLabel;
  final VoidCallback onSave;

  /// Título de la confirmación y etiqueta de accesibilidad: "Borrar serie".
  final String? deleteLabel;

  /// Si es nulo, no se muestra el botón de borrar.
  final VoidCallback? onDelete;

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('¿$deleteLabel?'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed == true) onDelete!();
  }

  @override
  Widget build(BuildContext context) {
    final red = resolveColor(context, CupertinoColors.destructiveRed);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          if (onDelete != null) ...[
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _confirmDelete(context),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(cardRadius),
                ),
                child: Icon(
                  CupertinoIcons.trash,
                  size: 22,
                  color: red,
                  semanticLabel: deleteLabel,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: PrimaryButton(label: saveLabel, onPressed: onSave),
          ),
        ],
      ),
    );
  }
}

/// Un suplemento de la guía: nombre, y debajo su dosis y su momento de toma.
///
/// Todo va apilado a lo ancho de la fila: las dosis reales son frases
/// ("1 g de EPA/DHA combinados al día"), no caben junto al nombre.
class SupplementTile extends StatelessWidget {
  const SupplementTile({super.key, required this.name, this.dose, this.timing});

  final String name;
  final String? dose;
  final String? timing;

  @override
  Widget build(BuildContext context) {
    // "Omega 3 (EPAs / DHAs)" → título "Omega 3" y aclaración "EPAs / DHAs".
    final (title, detail) = splitName(name);
    final secondary = textStyle(
      context,
      size: 13,
      color: CupertinoColors.secondaryLabel,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SupplementIcon(name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textStyle(context, weight: FontWeight.w600)),
                if (detail != null) Text(detail, style: secondary),
                if (dose != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    dose!,
                    style: textStyle(
                      context,
                      size: 15,
                      weight: FontWeight.w500,
                      color: accentColor,
                    ),
                  ),
                ],
                if (timing != null) ...[
                  const SizedBox(height: 2),
                  Text(timing!, style: secondary),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Icono de un frasco de medicamento: tapa, cuerpo y una cruz en la etiqueta.
///
/// Está dibujado a mano porque el paquete de iconos de iOS no trae ninguno
/// parecido. Toma tamaño y color del tema de iconos que lo rodea, así que se
/// comporta como cualquier otro icono (por ejemplo, en la barra de pestañas).
class PillBottleIcon extends StatelessWidget {
  const PillBottleIcon({super.key, this.size, this.color});

  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final side = size ?? theme.size ?? 24;
    return CustomPaint(
      size: Size.square(side),
      painter: _PillBottlePainter(
        color ?? theme.color ?? CupertinoColors.label.resolveFrom(context),
      ),
    );
  }
}

class _PillBottlePainter extends CustomPainter {
  const _PillBottlePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..color = color;

    // Tapa, más ancha que el cuello.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.22, h * 0.06, w * 0.56, h * 0.17),
        Radius.circular(w * 0.05),
      ),
      paint,
    );

    // Cuerpo, con una cruz recortada en la etiqueta.
    final body = Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.16, h * 0.28, w * 0.68, h * 0.66),
          Radius.circular(w * 0.12),
        ),
      )
      ..addRect(Rect.fromLTWH(w * 0.44, h * 0.44, w * 0.12, h * 0.34))
      ..addRect(Rect.fromLTWH(w * 0.33, h * 0.55, w * 0.34, h * 0.12));
    canvas.drawPath(body, paint);
  }

  @override
  bool shouldRepaint(_PillBottlePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Cómo se ve un suplemento: un icono o un símbolo corto, con su color.
class SupplementVisual {
  const SupplementVisual({required this.color, this.icon, this.symbol});

  /// Figura que lo representa (pescado para el omega 3), o…
  final IconData? icon;

  /// …su símbolo: la letra de una vitamina ("D3") o el del elemento de un
  /// mineral ("Mg"), como en la tabla periódica.
  final String? symbol;
  final Color color;

  /// El que corresponde al nombre del suplemento; una cápsula del color de
  /// la app si no se reconoce.
  static SupplementVisual of(String name) {
    final text = _plain(name);
    bool has(String pattern) => RegExp(pattern).hasMatch(text);

    // Vitaminas: su letra (y número, si lo tiene).
    final vitamin = RegExp(r'\bvitamina\s+([a-z]\d{0,2})\b').firstMatch(text);
    if (vitamin != null) {
      final letter = vitamin.group(1)!.toUpperCase();
      return SupplementVisual(
        symbol: letter,
        color: switch (letter[0]) {
          'D' => const Color(0xFFF97316),
          'C' => const Color(0xFFEAB308),
          'B' => const Color(0xFFDC2626),
          _ => const Color(0xFF16A34A),
        },
      );
    }

    // Minerales: el símbolo de su elemento.
    const minerals = {
      'magnesio': ('Mg', Color(0xFF6366F1)),
      'zinc': ('Zn', Color(0xFF0D9488)),
      'hierro': ('Fe', Color(0xFFB91C1C)),
      'calcio': ('Ca', Color(0xFF64748B)),
      'potasio': ('K', Color(0xFF7C3AED)),
      'selenio': ('Se', Color(0xFF0891B2)),
      'yodo': ('I', Color(0xFF9333EA)),
      'cromo': ('Cr', Color(0xFF475569)),
    };
    for (final MapEntry(key: word, value: (symbol, color))
        in minerals.entries) {
      if (has('\\b$word\\b')) {
        return SupplementVisual(symbol: symbol, color: color);
      }
    }

    // Lo demás: una figura que tenga que ver con lo que es.
    if (has(r'creatin')) {
      return const SupplementVisual(icon: Icons.bolt, color: Color(0xFFF59E0B));
    }
    if (has(r'prote|whey|caseina')) {
      return const SupplementVisual(
        icon: Icons.blender,
        color: Color(0xFF8B5CF6),
      );
    }
    if (has(r'omega|pescado|\bepa\b|\bdha\b|krill')) {
      return const SupplementVisual(
        icon: Icons.set_meal,
        color: Color(0xFF0284C7),
      );
    }
    if (has(r'cafe|pre.?entreno')) {
      return const SupplementVisual(
        icon: Icons.coffee,
        color: Color(0xFF92400E),
      );
    }
    if (has(r'melatonina')) {
      return const SupplementVisual(
        icon: Icons.nightlight_round,
        color: Color(0xFF4338CA),
      );
    }
    if (has(r'inositol')) {
      return const SupplementVisual(
        icon: Icons.balance,
        color: Color(0xFFDB2777),
      );
    }
    if (has(r'colageno')) {
      return const SupplementVisual(
        icon: Icons.healing,
        color: Color(0xFFE11D48),
      );
    }
    if (has(r'electrolito|suero')) {
      return const SupplementVisual(
        icon: Icons.water_drop,
        color: Color(0xFF06B6D4),
      );
    }
    if (has(r'ashwagandha|rhodiola|adaptog')) {
      return const SupplementVisual(icon: Icons.eco, color: Color(0xFF15803D));
    }
    if (has(r'probiotic')) {
      return const SupplementVisual(
        icon: Icons.science,
        color: Color(0xFF7E22CE),
      );
    }
    return const SupplementVisual(
      icon: CupertinoIcons.capsule_fill,
      color: accentColor,
    );
  }

  /// Minúsculas y sin acentos, para comparar.
  static String _plain(String text) {
    const accents = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u'};
    return text.toLowerCase().split('').map((c) => accents[c] ?? c).join();
  }
}

/// Icono de un suplemento, elegido por su nombre, en un cuadro de color.
class SupplementIcon extends StatelessWidget {
  const SupplementIcon(this.name, {super.key});

  final String name;

  @override
  Widget build(BuildContext context) {
    final visual = SupplementVisual.of(name);
    final color = resolveColor(context, visual.color);
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: switch (visual) {
        SupplementVisual(:final symbol?) => Text(
          symbol,
          style: TextStyle(
            fontFamily: appFontFamily,
            fontSize: symbol.length > 2 ? 13 : 16,
            fontWeight: FontWeight.w700,
            color: color,
            height: 1,
          ),
        ),
        SupplementVisual(:final icon) => Icon(icon, size: 21, color: color),
      },
    );
  }
}

/// Barra inferior fija con el botón principal de la pantalla.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(screenPadding, 8, screenPadding, 12),
        child: child,
      ),
    );
  }
}

/// Título de sección, en el estilo de las listas agrupadas de iOS.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: textStyle(context, size: 20, weight: FontWeight.w600),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Tarjeta redondeada que agrupa filas separadas por una línea fina.
class CardGroup extends StatelessWidget {
  const CardGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final divider = Container(
      height: 0.5,
      margin: const EdgeInsets.only(left: 16),
      color: resolveColor(context, CupertinoColors.separator),
    );
    return Container(
      decoration: BoxDecoration(
        color: resolveColor(context, cardColor),
        borderRadius: BorderRadius.circular(cardRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (index, child) in children.indexed) ...[
            if (index > 0) divider,
            child,
          ],
        ],
      ),
    );
  }
}

/// Fila de formulario: etiqueta a la izquierda y control a la derecha.
class FormRow extends StatelessWidget {
  const FormRow({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Text(label, style: textStyle(context)),
            const SizedBox(width: 12),
            Expanded(
              child: Align(alignment: Alignment.centerRight, child: child),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila que abre otra pantalla: un texto que ocupa todo el ancho disponible
/// (y se parte en varias líneas si es largo) y una flecha a la derecha.
///
/// Para textos variables, como el nombre de un ejercicio, en lugar de
/// [FormRow], cuya etiqueta está pensada para palabras cortas.
class NavigationRow extends StatelessWidget {
  const NavigationRow({
    super.key,
    required this.label,
    required this.onPressed,
    this.detail,
  });

  final String label;

  /// Texto secundario bajo la etiqueta.
  final String? detail;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
      onPressed: onPressed,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: textStyle(context)),
                if (detail != null)
                  Text(
                    detail!,
                    style: textStyle(
                      context,
                      size: 13,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            CupertinoIcons.chevron_forward,
            size: 16,
            color: resolveColor(context, CupertinoColors.tertiaryLabel),
          ),
        ],
      ),
    );
  }
}

/// Campo de texto sin borde, alineado a la derecha, para usar en [FormRow].
class RowTextField extends StatelessWidget {
  const RowTextField({
    super.key,
    required this.controller,
    required this.placeholder,
    this.keyboardType,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String placeholder;
  final TextInputType? keyboardType;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      keyboardType: keyboardType,
      autofocus: autofocus,
      textAlign: TextAlign.right,
      decoration: null,
      padding: const EdgeInsets.symmetric(vertical: 8),
      style: textStyle(context, weight: FontWeight.w500),
      placeholderStyle: textStyle(
        context,
        color: CupertinoColors.placeholderText,
      ),
    );
  }
}

/// Icono de un tipo de sesión dentro de un cuadro redondeado de color suave.
/// La figura de cada tipo de sesión: pesa, alberca, corredor y buzo.
IconData sessionTypeIcon(SessionType type) => switch (type) {
  SessionType.strength => Icons.fitness_center,
  SessionType.swim => Icons.pool,
  SessionType.run => Icons.directions_run,
  SessionType.apnea => Icons.scuba_diving,
};

/// Un color por tipo de sesión, para distinguirlas de un vistazo en la
/// lista.
Color sessionTypeColor(SessionType type) => switch (type) {
  SessionType.strength => const Color(0xFFEA580C),
  SessionType.swim => const Color(0xFF0284C7),
  SessionType.run => const Color(0xFF16A34A),
  SessionType.apnea => const Color(0xFF4F46E5),
};

class SessionTypeIcon extends StatelessWidget {
  const SessionTypeIcon(this.type, {super.key, this.size = 40});

  final SessionType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = sessionTypeColor(type);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(sessionTypeIcon(type), size: size * 0.55, color: color),
    );
  }
}

/// Campo de texto de ancho completo con fondo de tarjeta, para formularios.
class CardTextField extends StatelessWidget {
  const CardTextField({
    super.key,
    required this.controller,
    required this.placeholder,
    this.autofocus = false,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.sentences,
  });

  final TextEditingController controller;
  final String placeholder;
  final bool autofocus;
  final int maxLines;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      autofocus: autofocus,
      minLines: 1,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: resolveColor(context, cardColor),
        borderRadius: BorderRadius.circular(cardRadius),
      ),
      style: textStyle(context),
      placeholderStyle: textStyle(
        context,
        color: CupertinoColors.placeholderText,
      ),
    );
  }
}

/// Mensaje de error bajo un formulario.
class FormError extends StatelessWidget {
  const FormError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
      child: Text(
        message,
        style: textStyle(
          context,
          size: 14,
          color: CupertinoColors.destructiveRed,
        ),
      ),
    );
  }
}

/// Fila de formulario que abre un selector: muestra el valor elegido.
class PickerRow extends StatelessWidget {
  const PickerRow({
    super.key,
    required this.label,
    required this.value,
    required this.onPressed,
  });

  final String label;

  /// Texto del valor elegido; `null` muestra "Elegir" en color de acento.
  final String? value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: FormRow(
        label: label,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                value ?? 'Elegir',
                overflow: TextOverflow.ellipsis,
                style: textStyle(
                  context,
                  weight: FontWeight.w500,
                  color: value == null ? accentColor : CupertinoColors.label,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              CupertinoIcons.chevron_up_chevron_down,
              size: 14,
              color: resolveColor(context, CupertinoColors.tertiaryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila numerada de una lista de registros (series, bloques, intentos).
class RecordRow extends StatelessWidget {
  const RecordRow({
    super.key,
    required this.marker,
    required this.title,
    this.details = const [],
    this.muted = false,
    this.onTap,
  });

  /// Lo que va a la izquierda: normalmente [RowNumber] o [WarmupBadge].
  final Widget marker;
  final String title;

  /// Líneas secundarias bajo el título; las vacías se omiten.
  final List<String> details;

  /// Atenúa el título (se usa en las series de calentamiento).
  final bool muted;

  /// Si se indica, la fila se puede tocar (para editar) y muestra una flecha.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = _content(context);
    return onTap == null
        ? row
        : CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onTap,
            child: row,
          );
  }

  Widget _content(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Align(alignment: Alignment.centerLeft, child: marker),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textStyle(
                    context,
                    weight: muted ? FontWeight.w500 : FontWeight.w600,
                    color: muted
                        ? CupertinoColors.secondaryLabel
                        : CupertinoColors.label,
                  ),
                ),
                for (final line in details.where((l) => l.isNotEmpty))
                  Text(
                    line,
                    style: textStyle(
                      context,
                      size: 13,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              CupertinoIcons.chevron_forward,
              size: 16,
              color: resolveColor(context, CupertinoColors.tertiaryLabel),
            ),
        ],
      ),
    );
  }
}

class RowNumber extends StatelessWidget {
  const RowNumber(this.number, {super.key});

  final int number;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$number',
      style: textStyle(
        context,
        weight: FontWeight.w600,
        color: CupertinoColors.secondaryLabel,
      ),
    );
  }
}

/// Marca de serie de calentamiento: cuadro naranja con una "C" blanca.
class WarmupBadge extends StatelessWidget {
  const WarmupBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: resolveColor(context, CupertinoColors.systemOrange),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        'C',
        style: textStyle(
          context,
          size: 14,
          weight: FontWeight.w700,
          color: CupertinoColors.white,
        ).copyWith(height: 1),
      ),
    );
  }
}

/// Estado con un punto de color: "● En curso".
class StatusDot extends StatelessWidget {
  const StatusDot(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final color = resolveColor(context, accentColor);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: textStyle(
            context,
            size: 13,
            weight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Aviso de seguridad: fondo sólido y texto blanco, siempre legible.
class SafetyBanner extends StatelessWidget {
  const SafetyBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFC2410C),
        borderRadius: BorderRadius.circular(cardRadius),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            size: 20,
            color: CupertinoColors.white,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: textStyle(
                context,
                size: 14,
                weight: FontWeight.w600,
                color: CupertinoColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Muestra una hoja inferior con título y botón de cerrar. Sube con el teclado.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
}) {
  return showCupertinoModalPopup<T>(
    context: context,
    builder: (context) {
      final media = MediaQuery.of(context);
      return Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: ConstrainedBox(
          // La hoja nunca pasa de la zona visible: con el teclado abierto o
          // un formulario largo, su contenido se desplaza.
          constraints: BoxConstraints(
            maxHeight:
                media.size.height -
                media.viewInsets.bottom -
                media.padding.top -
                12,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: resolveColor(context, sheetColor),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  screenPadding,
                  8,
                  screenPadding,
                  12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: textStyle(
                              context,
                              size: 20,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancelar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: SingleChildScrollView(
                        // Nivel elevado: las tarjetas de la hoja usan su
                        // tono propio.
                        child: CupertinoUserInterfaceLevel(
                          data: CupertinoUserInterfaceLevelData.elevated,
                          child: Builder(builder: builder),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
