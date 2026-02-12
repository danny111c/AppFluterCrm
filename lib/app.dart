import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'config/theme.dart';
import 'config/app_routes.dart';


import 'presentation/screens/clientes_screen.dart';
import 'presentation/screens/proveedores_screen.dart';
import 'presentation/screens/cuentas_screen.dart';
import 'presentation/screens/ventas_screen.dart';
import 'presentation/screens/catalogo_screen.dart';
import 'presentation/screens/plantillas_screen.dart';
import 'presentation/screens/transacciones_screen.dart  ';
import 'presentation/widgets/navigation/fixed_sidebar_navigation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // ✅ 1. IMPORTAR RIVERPOD
// ✅ 2. IMPORTAR LOS PROVIDERS PARA PODER LIMPIARLOS
import 'domain/providers/cliente_provider.dart';
import 'domain/providers/venta_provider.dart';
import 'domain/providers/cuenta_provider.dart';



class MyApp extends ConsumerStatefulWidget { 
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> { 
  final Map<String, int> _routeIndexMap = {
    AppRoutes.CLIENTES: 0,
    AppRoutes.PROVEEDORES: 1,
    AppRoutes.CUENTAS: 2,
    AppRoutes.VENTAS: 3,
    AppRoutes.CATALOGO: 4,
        AppRoutes.TRANSACCIONES: 5, // <-- AÑADIR

    AppRoutes.PLANTILLAS: 6,
  };

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

    // ============================================================
  // ✅ AQUÍ ESTÁ LA LÓGICA DE NAVEGACIÓN LIMPIA
  // ============================================================
  void _handleNavigation(int index, String route) {
    
    // Si navegamos a VENTAS desde el menú, reseteamos todos los filtros
    if (route == AppRoutes.VENTAS) {
      ref.read(ventasProvider.notifier).search(null);           // Limpia buscador texto
      ref.read(ventasProvider.notifier).filterByCuenta(null);    // Limpia filtro por cuenta
      // Si añadiste filterByCliente anteriormente, inclúyelo aquí:
      // ref.read(ventasProvider.notifier).filterByCliente(null);
    }

    // Si navegamos a CLIENTES, limpiamos su buscador
    if (route == AppRoutes.CLIENTES) {
      ref.read(clientesProvider.notifier).search(null);
    }

    // Si navegamos a CUENTAS, limpiamos su buscador
    if (route == AppRoutes.CUENTAS) {
      ref.read(cuentasProvider.notifier).search('');
    }

    // Ejecuta la navegación
    navigatorKey.currentState!.pushNamedAndRemoveUntil(route, (Route<dynamic> route) => false);
  }
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'CRM Streaming',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,

      supportedLocales: const [
        Locale('es'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      initialRoute: AppRoutes.CLIENTES,
      routes: {
        AppRoutes.CLIENTES: (context) => _buildScreenWrapper(
              screenContent: const ClientesScreen(),
              currentIndex: _routeIndexMap[AppRoutes.CLIENTES] ?? 0,
            ),
        AppRoutes.PROVEEDORES: (context) => _buildScreenWrapper(
              screenContent: const ProveedoresScreen(),
              currentIndex: _routeIndexMap[AppRoutes.PROVEEDORES] ?? 1,
            ),
        AppRoutes.CUENTAS: (context) => _buildScreenWrapper(
              screenContent: const CuentasScreen(),
              currentIndex: _routeIndexMap[AppRoutes.CUENTAS] ?? 2,
            ),
        AppRoutes.VENTAS: (context) => _buildScreenWrapper(
              screenContent: const VentasScreen(),
              currentIndex: _routeIndexMap[AppRoutes.VENTAS] ?? 3,
            ),
        AppRoutes.CATALOGO: (context) => _buildScreenWrapper(
              screenContent: const CatalogoScreen(),
              currentIndex: _routeIndexMap[AppRoutes.CATALOGO] ?? 4,
            ),


                    AppRoutes.TRANSACCIONES: (context) => _buildScreenWrapper( // <-- AÑADIR ESTE BLOQUE
              screenContent: const TransaccionesScreen(),
              currentIndex: _routeIndexMap[AppRoutes.TRANSACCIONES] ?? 5,
            ),
        AppRoutes.PLANTILLAS: (context) => _buildScreenWrapper(
              screenContent: const PlantillasScreen(),
              currentIndex: _routeIndexMap[AppRoutes.PLANTILLAS] ?? 6,
            ),


      },
    );
  }

  // Método para construir el layout completo de la pantalla principal
  Widget _buildScreenWrapper({
    required Widget screenContent,
    required int currentIndex,
  }) {
    return Scaffold(
      body: Row(
        children: [
          // ===== CORRECCIÓN DEL LAYOUTBUILDER =====
          // Restauramos la lógica original que era correcta.
          LayoutBuilder(
            builder: (context, constraints) {
              return constraints.maxWidth < 600 
                ? Drawer(child: _buildSidebar(currentIndex))
                : _buildSidebar(currentIndex);
            },
          ),
          // =====================================
          Expanded(
            child: Material(
              child: Container(
                color: const Color(0xFFF5F5F5),
                child: screenContent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(int currentIndex) {
    // ===== CORRECCIÓN DE LA LLAMADA =====
    // Ahora, sin el parámetro 'pages', esta llamada es válida.
    return FixedSidebarNavigation(
      selectedIndex: currentIndex,
      onItemSelected: _handleNavigation,
    );
    // ====================================
  }
}