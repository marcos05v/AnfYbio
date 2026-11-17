import 'package:flutter/cupertino.dart';

import '../data/tables/sessions.dart';
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
class SessionTypeIcon extends StatelessWidget {
  const SessionTypeIcon(this.type, {super.key, this.size = 40});

  final SessionType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = resolveColor(context, accentColor);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(
        switch (type) {
          SessionType.strength => CupertinoIcons.bolt_fill,
          SessionType.swim => CupertinoIcons.drop_fill,
          SessionType.run => CupertinoIcons.speedometer,
          SessionType.apnea => CupertinoIcons.wind,
        },
        size: size * 0.5,
        color: color,
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
  });

  /// Lo que va a la izquierda: normalmente [RowNumber] o [WarmupBadge].
  final Widget marker;
  final String title;

  /// Líneas secundarias bajo el título; las vacías se omiten.
  final List<String> details;

  /// Atenúa el título (se usa en las series de calentamiento).
  final bool muted;

  @override
  Widget build(BuildContext context) {
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
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: resolveColor(context, sheetColor),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                // Nivel elevado: las tarjetas de la hoja usan su tono propio.
                CupertinoUserInterfaceLevel(
                  data: CupertinoUserInterfaceLevelData.elevated,
                  child: Builder(builder: builder),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
