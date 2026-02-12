// lib/presentation/widgets/navigation/fixed_sidebar_navigation.dart

import 'package:flutter/material.dart';
import '../../../config/app_routes.dart';

class FixedSidebarNavigation extends StatefulWidget {
  final int selectedIndex;
  // final List<Widget> pages; // <-- Eliminamos la propiedad
  final Function(int, String) onItemSelected;

  const FixedSidebarNavigation({
    super.key,
    this.selectedIndex = 0,
    // required this.pages, // <-- Eliminamos el requerimiento
    required this.onItemSelected,
  });

  @override
  State<FixedSidebarNavigation> createState() => _FixedSidebarNavigationState();
}

class _FixedSidebarNavigationState extends State<FixedSidebarNavigation> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Drawer(
            child: _buildSidebarContent(context),
          );
        } else {
          return Container(
            // --- CAMBIO 1: Color de fondo del contenedor principal ---
            color: const Color.fromARGB(255, 20, 20, 24), // Fondo completamente negro
            width: 250,
            child: _buildSidebarContent(context),
          );
        }
      },
    );
  }

  Widget _buildSidebarContent(BuildContext context) {
    return Column(
      children: [
        // Header de la barra de navegación sin línea separadora
        Container(
          color: const Color.fromARGB(255, 20, 20, 24),
          padding: const EdgeInsets.symmetric(vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.subscriptions, color: Colors.white, size: 40),
              const SizedBox(height: 10),
              Text(
                'Stream Gestion', 
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'CRM',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        // Lista de ítems de navegación
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              _buildSidebarItem(context, icon: Icons.people_alt_outlined, text: 'Clientes', index: 0, route: AppRoutes.CLIENTES),
              _buildSidebarItem(context, icon: Icons.business, text: 'Proveedores', index: 1, route: AppRoutes.PROVEEDORES),
              _buildSidebarItem(context, icon: Icons.inventory_2_outlined, text: 'Cuentas', index: 2, route: AppRoutes.CUENTAS),
              _buildSidebarItem(context, icon: Icons.shopping_cart_outlined, text: 'Ventas', index: 3, route: AppRoutes.VENTAS),
              _buildSidebarItem(context, icon: Icons.category_outlined, text: 'Catálogo', index: 4, route: AppRoutes.CATALOGO),
                            _buildSidebarItem(context, icon: Icons.history, text: 'Transacciones', index: 5, route: AppRoutes.TRANSACCIONES),

              _buildSidebarItem(context, icon: Icons.message_outlined, text: 'Plantillas', index: 6, route: AppRoutes.PLANTILLAS),
            ],
          ),
        ),
        // Footer con información de copyright
        const Padding(
          padding: EdgeInsets.all(20.0),
          child: Text(
            ' 2023 Stream Gestion CRM',
            style: TextStyle(color: Colors.white70, fontSize: 12), // Texto blanco con opacidad
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

// Método auxiliar para construir cada ítem de la barra lateral
  Widget _buildSidebarItem(BuildContext context, {required IconData icon, required String text, required int index, required String route}) {
    final bool isSelected = widget.selectedIndex == index;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: widget.selectedIndex == index 
          ? const Color.fromARGB(255, 58, 58, 58) // Azul en el Container
          : Colors.transparent,
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: ListTile(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        tileColor: Colors.transparent, // ListTile transparente
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
        leading: Icon(icon, color: Colors.white),
        title: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white,
            fontWeight: widget.selectedIndex == index ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () => widget.onItemSelected(index, route),
      ),
    );
  }

}