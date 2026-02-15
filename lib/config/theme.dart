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
    colorScheme: const ColorScheme.light( // Agregado const para optimización
      primary: primaryColor,
      secondary: accentColor,
      surface: cardBackgroundColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Color.fromARGB(255, 255, 255, 255),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Colors.white,
      selectionColor: Colors.white54,
      selectionHandleColor: Colors.white,
    ),

    // 👇 AQUÍ ESTÁ LA MAGIA PARA QUITAR EL ZOOM EN WINDOWS 👇
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.windows: NoTransitionsBuilder(), // Sin animación
        TargetPlatform.android: ZoomPageTransitionsBuilder(), // Android normal
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(), // iOS normal
      },
    ),
    // 👆 -------------------------------------------------- 👆

    // Configuración de Switch en blanco y negro
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith<Color?>(
        (Set<MaterialState> states) {
          if (states.contains(MaterialState.selected)) {
            return Colors.black; 
          }
          return Colors.white; 
        },
      ),
      trackColor: MaterialStateProperty.resolveWith<Color?>(
        (Set<MaterialState> states) {
          if (states.contains(MaterialState.selected)) {
            return Colors.white; 
          }
          return Colors.black; 
        },
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    // ... configuración tema oscuro
  );
}

// ✅ CLASE AUXILIAR PARA ELIMINAR LA ANIMACIÓN
// (Déjala aquí mismo, al final del archivo)
class NoTransitionsBuilder extends PageTransitionsBuilder {
  const NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Simplemente devuelve el hijo sin envolverlo en ninguna animación de Zoom o Fade
    return child;
  }
}