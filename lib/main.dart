// lib/main.dart
import 'package:flutter/material.dart';
import 'package:proyectofinal/infrastructure/supabase_config.dart';
import 'app.dart'; // Importa tu archivo app.dart
import 'package:flutter_riverpod/flutter_riverpod.dart'; // <-- 1. AÑADE LA IMPORTACIÓN

Future<void> main() async {
  // Asegúrate de que los bindings de Flutter estén inicializados antes de ejecutar la app
  WidgetsFlutterBinding.ensureInitialized(); 



  await SupabaseConfig.initialize();

  // 2. ENVUELVE TU APP CON PROVIDERSCOPE
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}