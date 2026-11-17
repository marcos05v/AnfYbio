import 'package:flutter/cupertino.dart';

const String appFontFamily = 'Poppins';

/// Color de acento. Tiene una variante por modo para mantener el contraste.
const CupertinoDynamicColor accentColor = CupertinoDynamicColor.withBrightness(
  color: Color(0xFF0A7C7C),
  darkColor: Color(0xFF3DD1D1),
);

/// Texto sobre el acento: blanco en claro, negro en oscuro.
const CupertinoDynamicColor onAccentColor =
    CupertinoDynamicColor.withBrightness(
      color: Color(0xFFFFFFFF),
      darkColor: Color(0xFF000000),
    );

/// Fondo de tarjetas y campos: gris muy claro sobre blanco, gris oscuro
/// sobre negro. Dentro de una hoja (nivel "elevado") sube un tono en modo
/// oscuro para seguir distinguiéndose del fondo de la hoja.
const CupertinoDynamicColor cardColor = CupertinoDynamicColor(
  color: Color(0xFFF3F4F6),
  darkColor: Color(0xFF1C1C1E),
  highContrastColor: Color(0xFFE9EAEE),
  darkHighContrastColor: Color(0xFF242426),
  elevatedColor: Color(0xFFF3F4F6),
  darkElevatedColor: Color(0xFF2C2C2E),
  highContrastElevatedColor: Color(0xFFE9EAEE),
  darkHighContrastElevatedColor: Color(0xFF363638),
);

/// Fondo de las hojas inferiores.
const CupertinoDynamicColor sheetColor = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFFFFFFF),
  darkColor: Color(0xFF1C1C1E),
);

const double cardRadius = 16;
const double screenPadding = 16;

/// Tema de la app. Con [brightness] nulo sigue al modo del sistema.
CupertinoThemeData buildTheme(Brightness? brightness) {
  const base = TextStyle(
    inherit: false,
    fontFamily: appFontFamily,
    fontSize: 17,
    height: 1.3,
    color: CupertinoColors.label,
  );
  return CupertinoThemeData(
    brightness: brightness,
    primaryColor: accentColor,
    primaryContrastingColor: onAccentColor,
    scaffoldBackgroundColor: CupertinoColors.systemBackground,
    barBackgroundColor: CupertinoColors.systemBackground,
    textTheme: CupertinoTextThemeData(
      primaryColor: accentColor,
      textStyle: base,
      actionTextStyle: base.copyWith(color: accentColor),
      navActionTextStyle: base.copyWith(
        color: accentColor,
        fontWeight: FontWeight.w500,
      ),
      navTitleTextStyle: base.copyWith(fontWeight: FontWeight.w600),
      navLargeTitleTextStyle: base.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      tabLabelTextStyle: base.copyWith(fontSize: 11),
    ),
  );
}

/// Estilo de texto del tema con ajustes puntuales.
TextStyle textStyle(
  BuildContext context, {
  double size = 17,
  FontWeight weight = FontWeight.w400,
  Color color = CupertinoColors.label,
}) {
  return CupertinoTheme.of(context).textTheme.textStyle.copyWith(
    fontSize: size,
    fontWeight: weight,
    color: CupertinoDynamicColor.resolve(color, context),
  );
}

Color resolveColor(BuildContext context, Color color) =>
    CupertinoDynamicColor.resolve(color, context);
