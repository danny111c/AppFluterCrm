// lib/config/theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  // Define tus colores aquí (ejemplo)
  static const Color primaryColor = Color(0xFF0056b3); // Azul oscuro
  static const Color accentColor = Color(0xFF007bff);   // Azul brillante
  static const Color backgroundColor = Color.fromARGB(255, 255, 255, 255); // Gris claro
  static const Color cardBackgroundColor = Color.fromARGB(255, 87, 87, 87); // Gris oscuro

  static ThemeData lightTheme = ThemeData(
    // Configura el tema aquí
    primaryColor: primaryColor,
    scaffoldBackgroundColor: const Color.fromARGB(255, 27, 25, 30),
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 1,
    ),
    colorScheme: ColorScheme.light(
      primary: primaryColor,
      secondary: accentColor,
      surface: cardBackgroundColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: const Color.fromARGB(255, 255, 255, 255),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Colors.white,
      selectionColor: Colors.white54,
      selectionHandleColor: Colors.white,
    ),

    // Configuración de Switch en blanco y negro
    switchTheme: SwitchThemeData(
      // Color del thumb (circulo)
      thumbColor: MaterialStateProperty.resolveWith<Color?>(
        (Set<MaterialState> states) {
          if (states.contains(MaterialState.selected)) {
            return Colors.black; // Encendido
          }
          return Colors.white; // Apagado
        },
      ),
      // Color del track (fondo)
      trackColor: MaterialStateProperty.resolveWith<Color?>(
        (Set<MaterialState> states) {
          if (states.contains(MaterialState.selected)) {
            return Colors.white; // Encendido
          }
          return Colors.black; // Apagado
        },
      ),
    ),
  );

  // Puedes añadir un darkTheme si lo necesitas
  static ThemeData darkTheme = ThemeData(
    // ... configuración tema oscuro
  );
}