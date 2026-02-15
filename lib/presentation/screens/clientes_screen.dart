import 'package:flutter/material.dart';
import 'package:proyectofinal/domain/models/cliente_model.dart';
import 'package:proyectofinal/domain/models/venta_model.dart'; // <--- FALTA ESTE
import 'package:proyectofinal/domain/models/plantilla_model.dart'; // <--- FALTA ESTE
import 'package:proyectofinal/infrastructure/repositories/cliente_repository.dart';
import 'package:proyectofinal/infrastructure/repositories/venta_repository.dart';
import 'package:proyectofinal/infrastructure/repositories/plantilla_repository.dart';
import 'package:proyectofinal/presentation/widgets/dialogs/confirm_dialog.dart';
import 'package:proyectofinal/presentation/widgets/buttons/add_button.dart';
import 'package:proyectofinal/presentation/widgets/modals/cliente_modal.dart';
import 'package:proyectofinal/presentation/widgets/tables/ReusableDataTablePanel.dart';
import 'package:proyectofinal/presentation/widgets/notifications/notification_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; 
import 'package:proyectofinal/domain/providers/cliente_provider.dart'; 
import 'package:shimmer/shimmer.dart'; 
import 'package:collection/collection.dart';
import 'package:intl/intl.dart'; // <--- PARA EL FORMATO DE FECHAS
import '../widgets/dialogs/seleccionar_mensaje_modal.dart';


import 'package:proyectofinal/domain/providers/venta_provider.dart'; // ✅ Para reconocer ventasProvider
import 'package:proyectofinal/config/app_routes.dart'; // ✅ Para reconocer AppRoutes
class ClientesScreen extends ConsumerStatefulWidget {
  const ClientesScreen({super.key});

  @override
  ConsumerState<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends ConsumerState<ClientesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ClienteRepository _clienteRepository = ClienteRepository(); 
  final VentaRepository _ventaRepo = VentaRepository(); 
  // ✅ NUEVO: Instanciamos el repositorio de plantillas
  final PlantillaRepository _plantillaRepo = PlantillaRepository(); 

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

Future<void> _enviarResumenServicios(Cliente cliente) async {
  try {
    // 1. Cargamos Ventas del cliente y todas las Plantillas guardadas
    final resultados = await Future.wait([
      _ventaRepo.getVentasActivasPorCliente(cliente.id!),
      _plantillaRepo.getPlantillas(),
    ]);

    final List<Venta> ventas = resultados[0] as List<Venta>;
    final List<Plantilla> plantillas = resultados[1] as List<Plantilla>;

    // ✅ COMENTAMOS O ELIMINAMOS EL BLOQUEO:
    /*
    if (ventas.isEmpty) {
      NotificationService.showCustomWarning(context, 'El cliente no tiene servicios activos.');
      return;
    }
    */

    // 2. Preparamos el mapa de variables inicial (Solo el nombre por ahora)
    Map<String, String> variablesFinales = {
      '[nombre_cliente]': cliente.nombre,
    };

    // 3. BUSCADOR DE LISTAS DINÁMICAS
    // Si el cliente no tiene ventas, este bucle simplemente no agregará nada a las listas
    final RegExp emailRegex = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]{2,}");

    for (var p in plantillas) {
      final regexLista = RegExp(r'\[LISTA:(.*?)\]');
      final matches = regexLista.allMatches(p.contenido);

      for (var match in matches) {
        String nombreMolde = match.group(1)!;
        final plantillaMolde = plantillas.firstWhereOrNull(
          (pl) => pl.nombre.trim().toLowerCase() == nombreMolde.trim().toLowerCase()
        );

        if (plantillaMolde != null) {
          StringBuffer buffer = StringBuffer();
          
          // Generamos el texto de la lista (si ventas está vacío, el buffer quedará vacío)
          for (var v in ventas) {
            List<String> lineasMolde = plantillaMolde.contenido.split('\n');
            List<String> lineasProcesadas = [];

            String perfilTexto = v.perfilAsignado?.trim() ?? "";
            bool esEmailReal = emailRegex.hasMatch(perfilTexto);
            bool esFamiliarPrivado = esEmailReal && perfilTexto.toLowerCase() != v.cuenta.correo.toLowerCase();

            for (String linea in lineasMolde) {
              bool debeMostrarLinea = true;
              if (esFamiliarPrivado && (linea.contains('[cuenta]') || linea.contains('[contrasena]'))) debeMostrarLinea = false;
              if (linea.contains('[perfil]') && perfilTexto.isEmpty) debeMostrarLinea = false;
              if (linea.contains('[pin_perfil]') && (v.pin == null || v.pin!.isEmpty)) debeMostrarLinea = false;

              if (debeMostrarLinea) {
                lineasProcesadas.add(linea
                  .replaceAll('[plataforma]', v.cuenta.plataforma.nombre.toUpperCase())
                  .replaceAll('[cuenta]', v.cuenta.correo)
                  .replaceAll('[contrasena]', v.cuenta.contrasena)
                  .replaceAll('[fecha_inicio]', v.fechaInicio)
                  .replaceAll('[fecha_final]', v.fechaFinal)
                  .replaceAll('[perfil]', perfilTexto)
                  .replaceAll('[pin_perfil]', v.pin ?? ''));
              }
            }
            buffer.writeln(lineasProcesadas.join('\n').trim());
            buffer.writeln(""); 
          }
          
          // Si no hay ventas, [LISTA:Nombre] se reemplaza por un espacio en blanco
          variablesFinales['[LISTA:$nombreMolde]'] = buffer.toString().trim();
        }
      }
    }

    // 4. ABRIR EL MODAL (Ahora se abrirá SIEMPRE)
    if (mounted) {
      await showDialog(
        context: context,
        builder: (_) => SeleccionarMensajeModal(
          title: 'Enviar Mensaje a ${cliente.nombre}',
          phoneNumber: cliente.contacto,
          dataForVariables: variablesFinales,
          tipoPlantilla: 'cliente',
            categoriaDestino: 'clientes', // ✅ AÑADIDO

        ),
      );
    }
  } catch (e) {
    print('🚨 Error en _enviarResumenServicios: $e');
  }
}



void _verVentasDelCliente(Cliente cliente) {
  // 1. Le decimos al buscador de ventas que filtre por este contacto
  ref.read(ventasProvider.notifier).search(cliente.contacto);

  // 2. Navegamos a la pantalla de Ventas
  Navigator.pushNamed(context, AppRoutes.VENTAS);
}


Future<void> _showClienteModal([Cliente? cliente]) async {
    // Variable para saber qué tipo de acción se hizo
    String accionRealizada = '';

    Future<bool> handleSave(Cliente clienteData) async {
      try {
        // Guardamos el resultado del saveCliente ('agregado', 'restaurado' o 'actualizado')
        accionRealizada = await ref.read(clientesProvider.notifier).saveCliente(clienteData);
        return true;
      } catch (e) {
        // Si el repositorio lanza el error "Ya existe un cliente activo"
        if (mounted) {
           NotificationService.showCustomError(context, e.toString().replaceFirst('Exception: ', ''));
        }
        return false;
      }
    }

    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => ClienteModal(
        cliente: cliente,
        onSave: handleSave,
        clienteRepository: _clienteRepository,
      ),
    );

    // ✅ LÓGICA DE NOTIFICACIÓN MEJORADA
    if (guardado == true && mounted) {
      switch (accionRealizada) {
        case 'restaurado':
          NotificationService.showSuccess(context, 'Cliente recuperado del historial');
          break;
        case 'agregado':
          NotificationService.showAdded(context, 'Cliente');
          break;
        case 'actualizado':
          NotificationService.showUpdated(context, 'Cliente');
          break;
      }
    }
  }

  Future<void> _eliminarCliente(Cliente cliente) async {
    try {
      if (cliente.id == null) return;
      final ventasCount = await ref.read(clientesProvider.notifier).getVentasCount(cliente.id!);
      
      if (ventasCount > 0) {
        if (mounted) {
          await ConfirmDialog.show(
            context: context,
            title: 'No se puede eliminar',
            message: 'Este cliente tiene $ventasCount ventas asociadas y no puede ser eliminado.',
            confirmText: 'Entendido',
            cancelText: '', 
          );
        }
        return; 
      }
    } catch (e) { return; }

    final confirmado = await ConfirmDialog.show(
      context: context,
      title: 'Confirmar Eliminación',
      message: '¿Estás seguro de que deseas eliminar al cliente "${cliente.nombre}"?',
      confirmText: 'Eliminar',
    );

    if (confirmado != true) return;

    final bool success = await ref.read(clientesProvider.notifier).deleteCliente(cliente);
    if (success && mounted) {
      NotificationService.showDeleted(context, 'Cliente');
    }
  }

  Widget _buildShimmerPlaceholder({double width = 100.0, double height = 16.0}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color.fromARGB(55, 61, 61, 61).withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clientesProvider);
    final notifier = ref.read(clientesProvider.notifier);

    const List<DataColumn> columns = [
      DataColumn(label: Text('Nombre')),
      DataColumn(label: Text('Contacto')),
      DataColumn(label: Text('Nota')),
      DataColumn(label: Text('Estado')),
      DataColumn(label: Text('Acciones')),
    ];

    List<Map<String, dynamic>> data;

    if (state.isLoading && state.clientes.isEmpty) {
      data = List.generate(
        10,
        (_) => {
          'Nombre': _buildShimmerPlaceholder(width: 120),
          'Contacto': _buildShimmerPlaceholder(width: 100),
          'Nota': _buildShimmerPlaceholder(width: 150),
          'Estado': _buildShimmerPlaceholder(width: 80, height: 28),
          'Acciones': Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildShimmerPlaceholder(width: 24, height: 24),
              const SizedBox(width: 8), 
              _buildShimmerPlaceholder(width: 24, height: 24),
              const SizedBox(width: 8), 
              _buildShimmerPlaceholder(width: 24, height: 24),
            ],
          ),
        },
      );
    } else {
      data = state.clientes.map((cliente) {
        final estadoWidget = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: cliente.esActivo ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            cliente.esActivo ? 'Activo' : 'Inactivo',
            style: TextStyle(
              color: cliente.esActivo ? Colors.green[300] : Colors.grey[400],
              fontWeight: FontWeight.bold,
            ),
          ),
        );

        return {
          'Nombre': Text(cliente.nombre),
          'Contacto': Text(cliente.contacto),
          'Nota': Text(cliente.nota ?? ''),
          'Estado': estadoWidget,
          'Acciones': Row(
            mainAxisSize: MainAxisSize.min,
            children: [

                  IconButton(
      icon: const Icon(Icons.shopping_bag_outlined, color: Colors.orangeAccent),
      tooltip: 'Ver todas las ventas de este cliente',
      onPressed: () => _verVentasDelCliente(cliente),
    ),
              IconButton(
  icon: const Icon(Icons.message, color: Colors.green), // ✅ Ícono de mensaje unificado
  tooltip: 'Contactar cliente', // ✅ Texto actualizado
                onPressed: () => _enviarResumenServicios(cliente),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blueAccent),
                onPressed: () => _showClienteModal(cliente),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                onPressed: () => _eliminarCliente(cliente),
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
          child: const Text('Gestión de Clientes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 31)),
        ),
        actions: [
          AddButton(onPressed: () => _showClienteModal()),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ReusableDataTablePanel(
                searchController: _searchController,
                onSearchSubmitted: (query) => notifier.search(query),
                onSearchChanged: (text) {
                  if (text.isEmpty) notifier.search(null);
                },
                columns: columns,
                data: data,
                isLoading: state.isLoading,
                currentPage: state.currentPage,
                totalPages: state.totalPages,
                onPageChanged: (page) => notifier.changePage(page),
              ),
            ),
          ],
        ),
      ),
    );
  }
}