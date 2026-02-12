import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/proveedor_model.dart';
import '../../domain/providers/proveedor_provider.dart';
import '../widgets/buttons/add_button.dart';
import '../widgets/tables/ReusableDataTablePanel.dart';
import '../widgets/modals/proveedor_modal.dart';
import '../widgets/dialogs/confirm_dialog.dart';
import 'package:proyectofinal/presentation/widgets/notifications/notification_service.dart';
import 'package:shimmer/shimmer.dart'; // <-- 1. IMPORTAR SHIMMER
import '../widgets/dialogs/seleccionar_mensaje_modal.dart';


import '../../domain/providers/cuenta_provider.dart'; // ✅ Para filtrar cuentas
import '../../config/app_routes.dart'; // ✅ Para navegar

class ProveedoresScreen extends ConsumerStatefulWidget {
  const ProveedoresScreen({super.key});

  @override
  ConsumerState<ProveedoresScreen> createState() => _ProveedoresScreenState();
}

class _ProveedoresScreenState extends ConsumerState<ProveedoresScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

void _verCuentasDelProveedor(Proveedor proveedor) {
  // 1. Le decimos al provider de cuentas que busque el nombre de este proveedor
  ref.read(cuentasProvider.notifier).search(proveedor.contacto);

  // 2. Navegamos a la pantalla de Cuentas
  Navigator.pushNamed(context, AppRoutes.CUENTAS);
}

  // Método para mostrar el modal de proveedor
Future<void> _showProveedorModal([Proveedor? proveedor]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => ProveedorModal(
        proveedor: proveedor,
        proveedorRepository: ref.read(proveedorRepositoryProvider),
      ),
    );

if (result != null && result['guardado'] == true && mounted) {
      final proveedorGuardado = result['proveedor'] as Proveedor;
      final bool fueRestaurado = result['restaurado'] ?? false; // Leemos si fue restaurado

      // LÓGICA DE NOTIFICACIÓN
     if (proveedor == null) {
        // AGREGADO O RESTAURADO
        if (fueRestaurado) {
          NotificationService.showSuccess(context, 'Proveedor recuperado del historial');
        } else {
          NotificationService.showAdded(context, 'Proveedor');
        }
        ref.read(proveedoresProvider.notifier).addProveedor(proveedorGuardado);
      } else {
        // ACTUALIZADO
        NotificationService.showUpdated(context, 'Proveedor');
        ref.read(proveedoresProvider.notifier).updateProveedor(proveedorGuardado);
      }
    }
  }

void _contactarProveedor(Proveedor proveedor) {
  // Preparamos las variables específicas del proveedor
  final data = {
    '[nombre_proveedor]': proveedor.nombre,
    '[contacto_proveedor]': proveedor.contacto,
    '[nota_proveedor]': proveedor.nota ?? '',
  };

  showDialog(
    context: context,
    builder: (_) => SeleccionarMensajeModal(
      title: 'Contactar a ${proveedor.nombre}',
      phoneNumber: proveedor.contacto,
      dataForVariables: data,
      tipoPlantilla: 'proveedor', // Filtra por tipo proveedor
      categoriaDestino: 'proveedores', // Filtra por la categoría de la pantalla
    ),
  );
}

  // Método para manejar la eliminación de un proveedor (LÓGICA FINAL)
  Future<void> _eliminarProveedor(Proveedor proveedor) async {
    if (proveedor.id == null) {
      if (mounted) NotificationService.showError(context, 'Error: El proveedor no tiene un ID válido.');
      return;
    }

    // 1. Verificar si el proveedor tiene cuentas activas
    final cuentasCount = await ref.read(proveedoresProvider.notifier).getCuentasCount(proveedor.id!);

    if (cuentasCount > 0) {
      // 2. Si tiene cuentas, mostrar directamente el modal de error
      if (mounted) {
        await ConfirmDialog.show(
          context: context,
          title: 'No se puede eliminar',
          message: 'Este proveedor tiene $cuentasCount cuenta(s) activa(s) y no puede ser eliminado.',
          confirmText: 'Entendido',
          cancelText: '', // Ocultamos el botón de cancelar
        );
      }
      return; // Salimos de la función
    }

    // 3. Si no tiene cuentas, pedir confirmación para eliminar
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Confirmar Eliminación',
      message: '¿Estás seguro de que deseas eliminar al proveedor "${proveedor.nombre}"?',
      confirmText: 'Eliminar',
    );

    if (confirmed != true) return; // El usuario canceló

    // 4. Si el usuario confirma, proceder con la eliminación
    try {
      await ref.read(proveedoresProvider.notifier).deleteProveedor(proveedor.id!);
      if (mounted) {
NotificationService.showDeleted(context, 'Proveedor');
      }
    } catch (e) {
      // Manejar cualquier otro error inesperado durante la eliminación
      if (mounted) {
        await ConfirmDialog.show(
          context: context,
          title: 'Error al eliminar',
          message: 'Ocurrió un error inesperado: ${e.toString()}',
          confirmText: 'Entendido',
          cancelText: '',
        );
      }
    }
  }

  // <-- 2. WIDGET AUXILIAR PARA CREAR UN PLACEHOLDER CON SHIMMER
Widget _buildShimmerPlaceholder({double width = 100.0, double height = 16.0}) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: const Color.fromARGB(55, 61, 61, 61)!.withOpacity(0.3),
      borderRadius: BorderRadius.circular(4),
    ),
  );
}




  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final state = ref.watch(proveedoresProvider);
                const List<DataColumn> columns = [
          DataColumn(label: Text('Nombre')),
          DataColumn(label: Text('Contacto')),
          DataColumn(label: Text('Nota')),
          DataColumn(label: Text('Estado')),
          DataColumn(label: Text('Acciones')),
        ];

        // <-- 3. LÓGICA MODIFICADA PARA GENERAR DATOS FANTASMA O REALES
        List<Map<String, dynamic>> data;

        if (state.isLoading && state.proveedores.isEmpty) {
          // Si está cargando y la lista está vacía, generamos filas fantasma
          data = List.generate(
            10, // Número de filas fantasma
            (_) => {
              'Nombre': _buildShimmerPlaceholder(width: 120),
              'Contacto': _buildShimmerPlaceholder(width: 100),
              'Nota': _buildShimmerPlaceholder(width: 150),
              'Estado': _buildShimmerPlaceholder(width: 80, height: 28),
'Acciones': Row( // <-- CORREGIDO
  mainAxisSize: MainAxisSize.min,
  children: [

    _buildShimmerPlaceholder(width: 24, height: 24),
    const SizedBox(width: 8), // Espacio entre los "iconos"
    _buildShimmerPlaceholder(width: 24, height: 24),
  ],
),
            },
          );
        } else {
          // Si no, usamos los datos reales del estado
          data = state.proveedores.map((proveedor) {
            final estadoWidget = Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: proveedor.esActivo ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                proveedor.esActivo ? 'Activo' : 'Inactivo',
                style: TextStyle(
                  color: proveedor.esActivo ? Colors.green[300] : Colors.grey[400],
                  fontWeight: FontWeight.bold,
                ),
              ),
            );

            return {
              'Nombre': Text(proveedor.nombre), // Se envuelve en un widget Text
              'Contacto': Text(proveedor.contacto), // Se envuelve en un widget Text
              'Nota': Text(proveedor.nota ?? ''), // Se envuelve en un widget Text
              'Estado': estadoWidget,
              'Acciones': Row(
                mainAxisSize: MainAxisSize.min,
                children: [
// ✅ NUEVO BOTÓN: CONTACTAR POR WHATSAPP
    IconButton(
      icon: const Icon(Icons.message, color: Colors.green),
      tooltip: 'Contactar Proveedor',
      onPressed: () => _contactarProveedor(proveedor),
    ),
                      // ✅ NUEVO BOTÓN: VER CUENTAS DEL PROVEEDOR
    IconButton(
      icon: const Icon(Icons.inventory_2_outlined, color: Colors.tealAccent),
      tooltip: 'Ver cuentas de este proveedor',
      onPressed: () => _verCuentasDelProveedor(proveedor),
    ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blueAccent),
                    onPressed: () => _showProveedorModal(proveedor),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () => _eliminarProveedor(proveedor),
                  ),
                ],
              ),
            };
          }).toList();
        }
                return Scaffold(
          appBar: AppBar(
            toolbarHeight: 100,
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0.0,
            title: Container(
              padding: const EdgeInsets.only(top: 20),
              child: const Text('Proveedores', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            actions: [
              AddButton(onPressed: () => _showProveedorModal()),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Expanded(
                  child: ReusableDataTablePanel(
                    searchController: _searchController,
                    onSearchSubmitted: (query) => ref.read(proveedoresProvider.notifier).searchProveedores(query),
                    onSearchChanged: (text) {
                      if (text.isEmpty) {
                        ref.read(proveedoresProvider.notifier).searchProveedores('');
                      }
                    },
                    isLoading: state.isLoading,
                    data: data, // <-- Pasamos la lista de datos ya preparada
                    columns: columns, // <-- Pasamos la lista de columnas
                    currentPage: state.currentPage,
                    totalPages: state.totalPages,
                    onPageChanged: (page) => ref.read(proveedoresProvider.notifier).changePage(page),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}