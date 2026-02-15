import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/plataforma_model.dart';
import '../../domain/providers/plataforma_provider.dart';
import '../../domain/models/tipo_cuenta_model.dart';
import '../../domain/providers/tipo_cuenta_provider.dart';
// CAMBIAMOS LA IMPORTACIÓN AL PANEL REUTILIZABLE
import '../../presentation/widgets/tables/ReusableDataTablePanel.dart';
import '../../presentation/widgets/modals/plataforma_modal.dart';
import '../../presentation/widgets/modals/tipo_cuenta_modal.dart';
import '../widgets/buttons/add_button.dart';

import '../../presentation/widgets/dialogs/confirm_dialog.dart';
import '../widgets/notifications/notification_service.dart';

class CatalogoScreen extends ConsumerStatefulWidget {
  const CatalogoScreen({super.key});

  @override
  ConsumerState<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends ConsumerState<CatalogoScreen> {
  int _selectedTableIndex = 0; // 0: plataformas, 1: tipos de cuenta
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _searchTipoCuentaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(plataformasProvider.notifier).loadPlataformas();
      ref.read(tiposCuentaProvider.notifier).loadTiposCuenta();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchTipoCuentaController.dispose();
    super.dispose();
  }

  // Métodos de navegación y búsqueda
  void _onPageChangedPlataformas(int page) => ref.read(plataformasProvider.notifier).loadPlataformas(page: page);
  void _onPageChangedTiposCuenta(int page) => ref.read(tiposCuentaProvider.notifier).loadTiposCuenta(page: page);
  
  void _onSearchPlataformas(String query) => ref.read(plataformasProvider.notifier).search(query);
  void _onSearchTiposCuenta(String query) => ref.read(tiposCuentaProvider.notifier).search(query);

@override
  Widget build(BuildContext context) {
    final plataformasState = ref.watch(plataformasProvider);
    final tiposCuentaState = ref.watch(tiposCuentaProvider);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 100,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Container(
          padding: const EdgeInsets.only(top: 20),
          child: const Text('Catálogo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 31)),
        ),
        actions: [
          AddButton(
            onPressed: () => _selectedTableIndex == 0 ? _onAddOrEditPlataforma() : _onAddOrEditTipoCuenta(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // ❌ SE ELIMINÓ EL ToggleButtons DE AQUÍ
            
            Expanded(
              child: _selectedTableIndex == 0
                  ? _buildPlataformasTable(plataformasState)
                  : _buildTiposCuentaTable(tiposCuentaState),
            ),
          ],
        ),
      ),
    );
  }
Widget _buildPlataformasTable(plataformasState) {
  // Añadimos <Map<String, dynamic>> después de la palabra 'map'
  final data = plataformasState.plataformas.map<Map<String, dynamic>>((p) {
    return {
      'Nombre': Text(p.nombre, style: const TextStyle(color: Colors.white)),
      'Nota': Text(p.nota ?? '', style: const TextStyle(color: Colors.white)),
      'Acciones': Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blueAccent),
            onPressed: () => _onAddOrEditPlataforma(plataforma: p),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: () => _onDeletePlataforma(p),
          ),
        ],
      ),
    };
  }).toList();

  return ReusableDataTablePanel(
    key: const ValueKey('plataformas'),
        filterActions: _buildFiltrosCatalogo(), // ✅ AÑADIDO

    columns: const [
      DataColumn(label: Text('Nombre')),
      DataColumn(label: Text('Nota')),
      DataColumn(label: Text('Acciones')),
    ],
    data: data,
    searchController: _searchController,
    onSearchSubmitted: _onSearchPlataformas,
    isLoading: plataformasState.isLoading,
    currentPage: plataformasState.currentPage,
    totalPages: plataformasState.totalPages,
    onPageChanged: _onPageChangedPlataformas,
  );
}

Widget _buildTiposCuentaTable(tiposCuentaState) {
  // Añadimos <Map<String, dynamic>> después de la palabra 'map'
  final data = tiposCuentaState.tiposCuenta.map<Map<String, dynamic>>((t) {
    return {
      'Nombre': Text(t.nombre, style: const TextStyle(color: Colors.white)),
      'Nota': Text(t.nota ?? '', style: const TextStyle(color: Colors.white)),
      'Acciones': Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blueAccent),
            onPressed: () => _onAddOrEditTipoCuenta(tipoCuenta: t),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: () => _onDeleteTipoCuenta(t),
          ),
        ],
      ),
    };
  }).toList();

  return ReusableDataTablePanel(
    key: const ValueKey('tipos_cuenta'),
        filterActions: _buildFiltrosCatalogo(), // ✅ AÑADIDO

    columns: const [
      DataColumn(label: Text('Nombre')),
      DataColumn(label: Text('Nota')),
      DataColumn(label: Text('Acciones')),
    ],
    data: data,
    searchController: _searchTipoCuentaController,
    onSearchSubmitted: _onSearchTiposCuenta,
    isLoading: tiposCuentaState.isLoading,
    currentPage: tiposCuentaState.currentPage,
    totalPages: tiposCuentaState.totalPages,
    onPageChanged: _onPageChangedTiposCuenta,
  );
}
  // --- MÉTODOS DE ACCIÓN ---
// PLATAFORMAS
  Future<void> _onAddOrEditPlataforma({Plataforma? plataforma}) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => PlataformaModal(
        plataforma: plataforma,
        onSave: (p) async {
          if (plataforma != null) {
            await ref.read(plataformasProvider.notifier).updatePlataforma(p);
          } else {
            await ref.read(plataformasProvider.notifier).addPlataforma(p);
          }
          return true;
        },
      ),
    );

    if (guardado == true && mounted) {
      // ✅ FORZAMOS RECARGA para que el totalCount se pida de nuevo a la DB
      ref.read(plataformasProvider.notifier).loadPlataformas();
      
      if (plataforma == null) {
        NotificationService.showAdded(context, 'Plataforma');
      } else {
        NotificationService.showUpdated(context, 'Plataforma');
      }
    }
  }

  Future<void> _onDeletePlataforma(Plataforma plataforma) async {
  if ((plataforma.cuentasCount ?? 0) > 0) {
    if (mounted) {
      await ConfirmDialog.show(
        context: context,
        title: 'No se puede eliminar',
        message: 'La plataforma "${plataforma.nombre}" está vinculada a ${plataforma.cuentasCount} cuenta(s) activas.',
        confirmText: 'Entendido',
        cancelText: '', 
      );
    }
    return;
  }

    final confirm = await ConfirmDialog.show(
      context: context, 
      title: 'Confirmar eliminación', 
      message: '¿Estás seguro de que deseas borrar la plataforma "${plataforma.nombre}"?'
    );

    if (confirm == true) {
      try {
        await ref.read(plataformasProvider.notifier).deletePlataforma(plataforma.id!);
        if (mounted) {
          // ✅ USAR showDeleted PARA EL ICONO DE BASURA
          NotificationService.showDeleted(context, 'Plataforma');
        }
      } catch (e) {
        if (mounted) NotificationService.showError(context, 'Error al eliminar: $e');
      }
    }
  }

 // TIPOS DE CUENTA
  Future<void> _onAddOrEditTipoCuenta({TipoCuenta? tipoCuenta}) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => TipoCuentaModal(
        tipoCuenta: tipoCuenta,
        onSave: (t) async {
          if (tipoCuenta != null) {
            await ref.read(tiposCuentaProvider.notifier).updateTipoCuenta(t);
          } else {
            await ref.read(tiposCuentaProvider.notifier).addTipoCuenta(t);
          }
          return true;
        },
      ),
    );

    if (guardado == true && mounted) {
      // ✅ FORZAMOS RECARGA para que el totalCount se pida de nuevo a la DB
      ref.read(tiposCuentaProvider.notifier).loadTiposCuenta();

      if (tipoCuenta == null) {
        NotificationService.showAdded(context, 'Tipo de Cuenta');
      } else {
        NotificationService.showUpdated(context, 'Tipo de Cuenta');
      }
    }
  }

Future<void> _onDeleteTipoCuenta(TipoCuenta tipoCuenta) async {
    // ✅ CAMBIO: Usamos cuentasCount en lugar de totalCount
    if ((tipoCuenta.cuentasCount ?? 0) > 0) {
      if (mounted) {
        await ConfirmDialog.show(
          context: context,
          title: 'No se puede eliminar',
          // ✅ CAMBIO: Mostramos la variable cuentasCount en el mensaje
          message: 'El tipo de cuenta "${tipoCuenta.nombre}" está asignado a ${tipoCuenta.cuentasCount} cuenta(s) activas.',
          confirmText: 'Entendido',
          cancelText: '',
        );
      }
      return;
    }

    final confirm = await ConfirmDialog.show(
      context: context, 
      title: 'Confirmar eliminación', 
      message: '¿Estás seguro de que deseas borrar el tipo de cuenta "${tipoCuenta.nombre}"?'
    );

    if (confirm == true) {
      try {
        await ref.read(tiposCuentaProvider.notifier).deleteTipoCuenta(tipoCuenta.id!);
        if (mounted) {
          NotificationService.showDeleted(context, 'Tipo de Cuenta');
        }
      } catch (e) {
        if (mounted) NotificationService.showError(context, 'Error al eliminar: $e');
      }
    }
  }
  // --- BARRA DE FILTROS PERSONALIZADA PARA CATÁLOGO ---
  Widget _buildFiltrosCatalogo() {
    const Color borderColor = Color.fromARGB(255, 35, 35, 35);
    const double borderWidth = 0.5;

    return Row(
      children: [
        // 1. SELECTOR IZQUIERDO (PLATAFORMAS / TIPOS)
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTabButton('PLATAFORMAS', 0),
              _buildTabButton('TIPOS DE CUENTA', 1),
            ],
          ),
        ),
        const SizedBox(width: 15),
        
        // 2. DIVIDER VERTICAL
        Container(width: 1, height: 25, color: borderColor),
        const SizedBox(width: 15),

        // 3. BUSCADOR INTEGRADO
        Expanded(
          child: SizedBox(
            height: 38,
            child: TextField(
              controller: _selectedTableIndex == 0 ? _searchController : _searchTipoCuentaController,
              onSubmitted: (val) => _selectedTableIndex == 0 ? _onSearchPlataformas(val) : _onSearchTiposCuenta(val),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Buscar en el catálogo...',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
                filled: true,
                fillColor: Colors.black,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8), 
                  borderSide: const BorderSide(color: Color(0xFF232323))
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8), 
                  borderSide: const BorderSide(color: Colors.white38, width: 0.5)
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton(String label, int index) {
    bool isSelected = _selectedTableIndex == index;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedTableIndex = index;
        // Opcional: limpiar búsquedas al cambiar
        _searchController.clear();
        _searchTipoCuentaController.clear();
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}