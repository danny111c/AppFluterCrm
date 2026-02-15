import 'package:flutter/material.dart';

class AppTheme {
  static const Color blackBackground = Color(0xFF000000); 
  static const Color surfaceColor = Color(0xFF121212); // Un gris casi negro para contraste

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: blackBackground,
    canvasColor: blackBackground,

    // 1. CONFIGURACIÓN GLOBAL DE TEXTO
    // .apply fuerza a que todos los estilos (body, display, titles) sean blancos
    textTheme: ThemeData.dark().textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),

    colorScheme: const ColorScheme.dark(
      primary: Colors.white, // Los botones primarios ahora serán blancos
      secondary: Colors.white,
      surface: surfaceColor,
      background: blackBackground,
      onSurface: Colors.white,
      onBackground: Colors.white,
    ),

    // 2. APPBAR (TÍTULOS)
    appBarTheme: const AppBarTheme(
      backgroundColor: blackBackground,
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Colors.white, 
        fontSize: 20, 
        fontWeight: FontWeight.bold
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),


  dividerColor: const Color.fromARGB(255, 35, 35, 35),

    // 3. TABLAS (DATATABLE)

  dataTableTheme: DataTableThemeData(
    // 2. Ponlo en 0.5 o 1.0. 
    // Si 0.5 se ve borroso en tu monitor, usa 1.0 pero con un color más oscuro.
    dividerThickness: 0.5, 
    headingRowColor: MaterialStateProperty.all(const Color(0xFF0A0A0A)),
      dataRowColor: MaterialStateProperty.all(blackBackground),
      // Forzamos cabeceras blancas
      headingTextStyle: const TextStyle(
        color: Colors.white, 
        fontWeight: FontWeight.bold
      ),
      // Forzamos celdas blancas
      dataTextStyle: const TextStyle(color: Colors.white),
    ),

    // 4. CARDS Y DIÁLOGOS
    dialogBackgroundColor: surfaceColor,
    cardTheme: CardThemeData(
      color: surfaceColor,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    // 5. INPUTS (BUSCADORES Y FORMULARIOS)
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1A1A1A),
      // Color del texto que se escribe y de las etiquetas
      labelStyle: const TextStyle(color: Colors.white),
      hintStyle: const TextStyle(color: Colors.white54), 
      prefixIconColor: Colors.white,
      suffixIconColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    ),

    // 6. BOTONES
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black, // Texto negro sobre botón blanco para que se lea
      ),
    ),

    // Animación de Windows
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.windows: NoTransitionsBuilder(),
      },
    ),
  );

  static ThemeData darkTheme = lightTheme;
}

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
    return child;
  }
}