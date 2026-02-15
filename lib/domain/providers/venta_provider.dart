import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../infrastructure/repositories/venta_repository.dart';
import '../models/venta_model.dart';
import 'cuenta_provider.dart'; // Importa el provider de cuentas
import 'historial_ventas_provider.dart'; // Importa el provider de historial de ventas
import 'cuenta_provider.dart'; // ¡Asegúrate de que esté aquí!
import 'package:collection/collection.dart'; // <-- 1. AÑADE ESTE IMPORT
import '../models/cuenta_model.dart'; // <-- 2. IMPORTA EL MODELO DIRECTAMENTE

// --- Provider para el Repositorio ---
final ventaRepositoryProvider = Provider((ref) => VentaRepository());

// --- Clase de Estado ---
class VentasState {
  final List<Venta> ventas;
  final bool isLoading;
  final int currentPage;
  final int totalPages;
  final String? searchQuery;
  final String? cuentaId; // Para filtrar por cuenta
  final bool sortByRecent; // Para el ordenamiento
final String? filterInfo; // ✅ Nueva propiedad

  // NUEVOS CAMPOS PARA FILTROS
  final String? filterPlataformaId;
  final int? filterMaxDias;
  final bool filterSoloProblemas;

  VentasState({
    this.ventas = const [],
    this.isLoading = false,
    this.currentPage = 1,
    this.totalPages = 1,
    this.searchQuery,
    this.cuentaId,
    this.sortByRecent = false,
    this.filterInfo,
    this.filterPlataformaId,
    this.filterMaxDias,
    this.filterSoloProblemas = false,
      });

  VentasState copyWith({
    List<Venta>? ventas,
    bool? isLoading,
    int? currentPage,
    int? totalPages,
    String? searchQuery,
    String? cuentaId,
    bool? sortByRecent,
    bool resetCuentaId = false, // Para limpiar el filtro de cuenta
    String? filterInfo,
    String? filterPlataformaId,
    int? filterMaxDias,
    bool? filterSoloProblemas,
  }) {
    return VentasState(
      ventas: ventas ?? this.ventas,
      isLoading: isLoading ?? this.isLoading,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      searchQuery: searchQuery ?? this.searchQuery,
      cuentaId: resetCuentaId ? null : cuentaId ?? this.cuentaId,
      sortByRecent: sortByRecent ?? this.sortByRecent,
      filterInfo: filterInfo ?? this.filterInfo,
      filterPlataformaId: filterPlataformaId ?? this.filterPlataformaId,
      filterMaxDias: filterMaxDias ?? this.filterMaxDias,
      filterSoloProblemas: filterSoloProblemas ?? this.filterSoloProblemas,
    );
  }
}

// --- El Notifier ---



// --- El Notifier Modificado ---
class VentasNotifier extends StateNotifier<VentasState> {
  final Ref _ref;
  final VentaRepository _ventaRepo;
  final int _perPage = 10;
  RealtimeChannel? _ventaChannel;
  RealtimeChannel? _clienteChannel; // Canal para escuchar cambios en clientes

  // 2. Modifica el constructor para aceptar Ref
  VentasNotifier(this._ref) 
    : _ventaRepo = _ref.read(ventaRepositoryProvider),
      super(VentasState()) {
    loadVentas();
    _listenToChanges();
    _listenToDependencies();
  }
  // 4. Añade el método para escuchar al provider de cuentas
  // ====================== DEBUGGING AQUÍ ======================
  void _listenToDependencies() {
    _ref.listen<CuentasState>(cuentasProvider, (previous, next) {
      // 🎯 LOG 1: ¿Se activa el listener?
      print('🔵 [LOG 1] ¡LISTENER DE CUENTAS EN VENTAS SE ACTIVÓ!');
      
      final hayCambiosReales = !const DeepCollectionEquality().equals(previous?.cuentas, next.cuentas);
      
      // 🎯 LOG 2: ¿La comparación de listas detecta un cambio?
      print('🔵 [LOG 2] ¿Se detectaron cambios en la lista de cuentas? -> $hayCambiosReales');

      if (hayCambiosReales) {
        _updateVentasConNuevasCuentas(next.cuentas);
      }
    });
  }

  void _updateVentasConNuevasCuentas(List<Cuenta> cuentasActuales) {
    if (state.ventas.isEmpty) {
        print('🟡 [LOG 3] Saltando actualización porque la lista de ventas está vacía.');
        return;
    }
    
    print('🟡 [LOG 3] Iniciando _updateVentasConNuevasCuentas...');

    final cuentasMap = {for (var c in cuentasActuales) c.id: c};
    bool seHizoAlgunaActualizacion = false;

    final ventasActualizadas = state.ventas.map((ventaVieja) {
      final nuevaInfoCuenta = cuentasMap[ventaVieja.cuenta.id];

      // 🎯 LOG 4: ¿La comparación de objetos individuales detecta el cambio?
      if (nuevaInfoCuenta != null && nuevaInfoCuenta != ventaVieja.cuenta) {
        print('🟢 [LOG 4] ¡ÉXITO! Se encontró un cambio para la Venta ID: ${ventaVieja.id}');
        print('   - Nombre Plataforma VIEJO: ${ventaVieja.cuenta.plataforma.nombre}');
        print('   - Nombre Plataforma NUEVO: ${nuevaInfoCuenta.plataforma.nombre}');
        seHizoAlgunaActualizacion = true;
        return ventaVieja.copyWith(cuenta: nuevaInfoCuenta);
      }
      return ventaVieja;
    }).toList();

    // 🎯 LOG 5: ¿Se va a emitir un nuevo estado?
    if (seHizoAlgunaActualizacion) {
      print('🟢 [LOG 5] Se detectaron cambios. ¡ACTUALIZANDO EL ESTADO DE VENTAS!');
      state = state.copyWith(ventas: ventasActualizadas);
    } else {
      print('🔴 [LOG 5] NO se detectaron cambios a nivel de objeto. NO se actualiza el estado.');
    }
  }
  // ====================== FIN DEBUGGING ======================


Future<void> loadVentas({int page = 1, bool showLoading = true}) async {
    if (showLoading) state = state.copyWith(isLoading: true);

    final orderBy = state.sortByRecent ? 'created_at' : 'fecha_final';
    final orderDesc = state.sortByRecent ? true : false;

    try {
      final totalCount = await _ventaRepo.getVentasCount(
        searchQuery: state.searchQuery,
        cuentaId: state.cuentaId,
        orderBy: orderBy,
        orderDesc: orderDesc,
      );
      
      final ventas = await _ventaRepo.getVentas(
        page: page,
        perPage: _perPage,
        searchQuery: state.searchQuery,
        cuentaId: state.cuentaId,
        orderBy: orderBy,
        orderDesc: orderDesc,
        // ENVIAR NUEVOS FILTROS AL REPOSITORIO
        plataformaId: state.filterPlataformaId,
        diasFilter: state.filterMaxDias,
        soloProblemas: state.filterSoloProblemas,
      );

      state = state.copyWith(
        ventas: ventas,
        isLoading: false,
        currentPage: page,
        totalPages: (totalCount / _perPage).ceil() > 0 ? (totalCount / _perPage).ceil() : 1,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
}

  Future<void> changePage(int page) async {
    await loadVentas(page: page);
  }

  Future<void> search(String? query) async {
    state = state.copyWith(searchQuery: query, currentPage: 1);
    await loadVentas(page: 1);
  }

Future<void> filterByCuenta(String? cuentaId, {String? info}) async {
  state = state.copyWith(
    cuentaId: cuentaId, 
    filterInfo: info, // ✅ Guardamos el correo o info
    resetCuentaId: cuentaId == null, 
    currentPage: 1
  );
  await loadVentas(page: 1);
}

  Future<void> toggleSortByRecent() async {
    print('[VENTAS_PROVIDER] toggleSortByRecent | Estado previo: sortByRecent=${state.sortByRecent}');
    // Limpiar ventas antes de recargar para evitar UI vacía
    final nuevoSort = !state.sortByRecent;
    state = state.copyWith(ventas: [], isLoading: true, sortByRecent: nuevoSort);
    print('[VENTAS_PROVIDER] toggleSortByRecent | Estado nuevo: sortByRecent=$nuevoSort (ACTIVADO: ${nuevoSort ? 'MÁS RECIENTE' : 'FECHA FINAL'})');
    await loadVentas(page: 1);
  }

  Future<void> refresh() async {
    await loadVentas(page: state.currentPage, showLoading: true);
  }

  // Corregido: Quitado el argumento 'ref' innecesario
// Busca tu saveVenta en el Notifier y déjalo así:
Future<bool> saveVenta(Venta venta, {String? perfilId}) async { 
  try {
    if (venta.id == null) {
      await _ventaRepo.addVenta(venta, perfilId: perfilId); 
    } else {
      // !!! ASEGÚRATE DE QUE ESTO TENGA EL perfilId !!!
      await _ventaRepo.updateVenta(venta, perfilId: perfilId);
    }
    refresh(); 
    return true;
  } catch (e) {
    return false;
  }
}

  // Corregido: Quitado el argumento 'ref' innecesario
Future<bool> deleteVenta(Venta venta) async { // <--- Cambia el parámetro de String a Venta
  try {
    await _ventaRepo.deleteVentaConObjeto(venta);
    refresh(); // Recargar lista
    return true;
  } catch (e) {
    return false;
  }
}

  void _listenToChanges() {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Listener para la tabla 'ventas'
    _ventaChannel = Supabase.instance.client
        .channel('public:ventas:provider:$now')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'ventas',
            callback: (payload) {
              print('[VENTAS_PROVIDER] Cambio detectado en VENTAS');
              if (payload.newRecord != null || payload.oldRecord != null) {
                Future.microtask(() {
                  loadVentas(page: state.currentPage, showLoading: false);
                });
              }
            })
        .subscribe();

    // Listener para la tabla 'clientes'
    _clienteChannel = Supabase.instance.client
        .channel('public:clientes:provider_ventas:$now') // Canal único
        .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'clientes',
            callback: (payload) {
              print('[VENTAS_PROVIDER] Cambio detectado en CLIENTES, actualizando ventas...');
              Future.microtask(() {
                loadVentas(page: state.currentPage, showLoading: false);
              });
            })
        .subscribe();

// 1. Declara la variable arriba con los otros canales
RealtimeChannel? _perfilChannel;

// 2. Dentro de _listenToChanges() añade esto:
_perfilChannel = Supabase.instance.client
    .channel('public:perfiles:provider:$now')
    .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'perfiles',
        callback: (payload) {
          print('[VENTAS_PROVIDER] Cambio detectado en la tabla PERFILES');
          // Cuando cambies un PIN maestro, refrescamos las ventas para ver el cambio
          refresh(); 
        })
    .subscribe();

    Supabase.instance.client
    .channel('public:perfiles:sync')
    .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'perfiles', // <--- ESCUCHAMOS LA TABLA DE PERFILES
        callback: (payload) {
          print('🔔 Cambio en Perfil Maestro detectado. Refrescando tabla de ventas...');
          refresh(); // Esto recarga la lista de ventas automáticamente
        })
    .subscribe();
  }

  

  @override
  void dispose() {
    _ventaChannel?.unsubscribe();
    _clienteChannel?.unsubscribe();
    super.dispose();
  }

  // Añadir este método al final del Notifier
void setFiltros({
  String? plataformaId,
  int? maxDias,
  bool? soloProblemas,
  String? query,
}) {
  // Reset de estado con valores reales (evitando el error del ?? de copyWith)
  state = VentasState(
    ventas: state.ventas,
    isLoading: true,
    currentPage: 1,
    totalPages: state.totalPages,
    searchQuery: query,
    cuentaId: state.cuentaId,
    filterInfo: state.filterInfo,
    sortByRecent: state.sortByRecent,
    filterPlataformaId: plataformaId, 
    filterMaxDias: maxDias,
    filterSoloProblemas: soloProblemas ?? false,
  );
  loadVentas(page: 1, showLoading: false);
}
}

// --- El Provider Final Modificado ---
final ventasProvider = StateNotifierProvider<VentasNotifier, VentasState>((ref) {
  // 6. Pasa el 'ref' al constructor
  return VentasNotifier(ref);
});
