// ===== CÓDIGO CORRECTO Y COMPLETO PARA cuenta_provider.dart =====

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../infrastructure/repositories/cuenta_repository.dart';
import '../../infrastructure/repositories/venta_repository.dart'; // Necesario para la lógica de borrado
import '../../domain/models/cuenta_model.dart';
import 'plataforma_provider.dart';   // ¡Añade esto!
import 'tipo_cuenta_provider.dart'; // ¡Añade esto!
import 'package:collection/collection.dart';
// --- Providers para los Repositorios ---
final cuentaRepositoryProvider = Provider((ref) => CuentaRepository());
final ventaRepositoryProvider = Provider((ref) => VentaRepository());

// --- Clase de Estado (Soluciona errores de 'currentPage' y 'totalPages') ---
class CuentasState {
  final List<Cuenta> cuentas;
  final bool isLoading;
  final int currentPage;
  final int totalPages;
  final String? searchQuery;
  final CuentaSortOption sortOption;
  final bool ordenarPorRecientes; // <--- NUEVO: bandera para el switch

  CuentasState({
    this.cuentas = const [],
    this.isLoading = false,
    this.currentPage = 1,
    this.totalPages = 1,
    this.searchQuery,
    this.sortOption = CuentaSortOption.porFechaFinal,
    this.ordenarPorRecientes = false,
  });

  CuentasState copyWith({
    List<Cuenta>? cuentas,
    bool? isLoading,
    int? currentPage,
    int? totalPages,
    String? searchQuery,
    CuentaSortOption? sortOption,
    bool? ordenarPorRecientes,
  }) {
    return CuentasState(
      cuentas: cuentas ?? this.cuentas,
      isLoading: isLoading ?? this.isLoading,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      searchQuery: searchQuery ?? this.searchQuery,
      sortOption: sortOption ?? this.sortOption,
      ordenarPorRecientes: ordenarPorRecientes ?? this.ordenarPorRecientes,
    );
  }
}


// --- El Notifier (Soluciona errores de 'saveCuenta', 'deleteCuenta', 'changePage') ---
class CuentasNotifier extends StateNotifier<CuentasState> {
  final Ref _ref; // <-- 1. Añade una referencia a Ref
  final CuentaRepository _cuentaRepo;
  final VentaRepository _ventaRepo;
  final int _perPage = 10;
  RealtimeChannel? _cuentaChannel;
  RealtimeChannel? _proveedorChannel; // Canal para escuchar cambios en proveedores

  // 2. Modifica el constructor para aceptar Ref
  CuentasNotifier(this._ref) 
    : _cuentaRepo = _ref.read(cuentaRepositoryProvider),
      _ventaRepo = _ref.read(ventaRepositoryProvider),
      super(CuentasState()) {
    _loadCuentas();
    _listenToChanges();
    _listenToDependencies(); // <-- 3. Llama al nuevo método de escucha
  }
   // 4. Añade el método para escuchar a los providers de catálogo
void _listenToDependencies() {
  // Listener para Plataformas (lo dejamos para comparar)
  _ref.listen<PlataformasState>(plataformasProvider, (previous, next) {
    if (!const DeepCollectionEquality().equals(previous?.plataformas, next.plataformas)) {
      print('✅ LISTENER PLATAFORMA: Cambio detectado!');
      _updateCuentasConNuevosDatos();
    }
  });

  // Listener para Tipos de Cuenta (AQUÍ HACEMOS EL CAMBIO CRÍTICO)
  // Listener para Tipos de Cuenta (AQUÍ ESTÁ NUESTRO FOCO)
  _ref.listen<TiposCuentaState>(tiposCuentaProvider, (previous, next) {
    print('----------------------------------------------------');
    print('>>> LISTENER DE TIPO DE CUENTA SE HA DISPARADO <<<');

    // Comprobemos si las listas son nulas o no
    final prevList = previous?.tiposCuenta;
    final nextList = next.tiposCuenta;
    print('   - Lista PREVIA existe: ${prevList != null}, tamaño: ${prevList?.length}');
    print('   - Lista NUEVA existe: ${nextList != null}, tamaño: ${nextList.length}');
    
    // Imprimamos el contenido de ambas listas para verlas
    if (prevList != null) {
      print('   - Contenido PREVIO: ${prevList.map((tc) => tc.nombre).toList()}');
    }
    print('   - Contenido NUEVO:   ${nextList.map((tc) => tc.nombre).toList()}');

    // La comparación crucial
    final hayCambios = !const DeepCollectionEquality().equals(prevList, nextList);
    
    if (hayCambios) {
      print('   - RESULTADO: ✅ ¡SÍ se detectaron cambios!');
      print('----------------------------------------------------');
      _updateCuentasConNuevosDatos();
    } else {
      print('   - RESULTADO: ⚠️ NO se detectaron cambios.');
      print('----------------------------------------------------');
    }
  });
}

   // 5. Añade el método que hace la actualización en memoria
void _updateCuentasConNuevosDatos() {
  // NO salimos si la lista está vacía. 
  // Si está vacía, no se hará nada en el bucle .map, lo cual es correcto.
  print('>> _updateCuentasConNuevosDatos: Ejecutando actualización en memoria.');

  // Leemos las listas de catálogos más recientes en el momento de la ejecución
  final plataformasMap = {for (var p in _ref.read(plataformasProvider).plataformas) p.id: p};
  final tiposCuentaMap = {for (var t in _ref.read(tiposCuentaProvider).tiposCuenta) t.id: t};

  // Esta variable es clave. Nos dirá si realmente hubo un cambio.
  bool seHizoUnCambioReal = false;

  final cuentasActualizadas = state.cuentas.map((cuentaVieja) {
    final nuevaPlataforma = plataformasMap[cuentaVieja.plataforma.id];
    final nuevoTipoCuenta = tiposCuentaMap[cuentaVieja.tipoCuenta.id];
    
    // Comprobamos si hay un cambio real que necesite una nueva instancia de Cuenta
    if ((nuevaPlataforma != null && nuevaPlataforma != cuentaVieja.plataforma) ||
        (nuevoTipoCuenta != null && nuevoTipoCuenta != cuentaVieja.tipoCuenta)) {
      
      seHizoUnCambioReal = true; // Marcamos que hubo un cambio
      print('   -> Actualizando datos para la cuenta: ${cuentaVieja.correo}');
      
      return cuentaVieja.copyWith(
        plataforma: nuevaPlataforma, // copyWith se encargará de usar el nuevo o mantener el viejo
        tipoCuenta: nuevoTipoCuenta,
      );
    }
    // Si no hay cambios para esta cuenta, devolvemos la instancia original.
    return cuentaVieja;
  }).toList();

  // SOLO actualizamos el estado si realmente se reconstruyó al menos un objeto Cuenta.
  // Esto evita bucles infinitos y notificaciones innecesarias.
  if (seHizoUnCambioReal) {
    print('>> ¡Cambio real detectado! Emitiendo nuevo estado para Cuentas.');
    state = state.copyWith(cuentas: cuentasActualizadas);
  } else {
    print('>> No se necesitaron cambios en los objetos Cuenta existentes.');
  }
}

  // ===== AÑADE ESTE MÉTODO COMPLETO AQUÍ =====
void toggleOrdenarPorRecientes(bool value) {
  // 1. Vacía la lista y marca loading → skeleton aparece
  state = state.copyWith(
    cuentas: [],           // ← clave
    isLoading: true,
    ordenarPorRecientes: value,
  );

  // 2. Recarga la página 1 con el nuevo orden
  _loadCuentas(
    page: 1,
    searchQuery: state.searchQuery,
    ordenarPorRecientes: value,
    showLoading: false,   // ya está en true arriba
  );
}



  Future<void> _loadCuentas({int page = 1, String? searchQuery, CuentaSortOption? sortOption, bool showLoading = true, bool? ordenarPorRecientes}) async {
    final ordenarRecientes = ordenarPorRecientes ?? state.ordenarPorRecientes;
    if (showLoading) {
      state = state.copyWith(isLoading: true);
    }
    try {
      final totalCount = await _cuentaRepo.getCuentasCount(searchQuery: searchQuery);
      final totalPages = (totalCount / _perPage).ceil();
      final actualSortOption = ordenarRecientes ? CuentaSortOption.porCreacionReciente : (sortOption ?? state.sortOption);
      final cuentas = await _cuentaRepo.getCuentas(
          page: page, perPage: _perPage, searchQuery: searchQuery, sortOption: actualSortOption);
      
      // ===== LOGS CORREGIDOS =====
      for (int i = 0; i < cuentas.length; i++) {
        final cuenta = cuentas[i];
        print('[CUENTAS_PROVIDER] Cuenta $i:');
        print('[CUENTAS_PROVIDER] - correo: ${cuenta.correo}');
        print('[CUENTAS_PROVIDER] - plataforma.nombre: ${cuenta.plataforma.nombre}'); // <- LEER DEL OBJETO
        print('[CUENTAS_PROVIDER] - tipoCuenta.nombre: ${cuenta.tipoCuenta.nombre}'); // <- LEER DEL OBJETO
        print('[CUENTAS_PROVIDER] - proveedor.nombre: ${cuenta.proveedor.nombre}'); // <- LEER DEL OBJETO
      }
      
      state = state.copyWith(
        cuentas: cuentas,
        isLoading: false,
        currentPage: page,
        totalPages: totalPages > 0 ? totalPages : 1,
        searchQuery: searchQuery,
        sortOption: sortOption ?? state.sortOption,
      );
    } catch (e) {
      print('[ERROR] _loadCuentas: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  // MÉTODO QUE FALTABA
  Future<void> changePage(int page) async {
    await _loadCuentas(page: page, searchQuery: state.searchQuery, sortOption: state.sortOption);
  }

  // MÉTODO QUE FALTABA
  Future<bool> saveCuenta(Cuenta cuenta) async {
    try {
      if (cuenta.id == null) {
        await _cuentaRepo.addCuenta(cuenta);
      } else {
        await _cuentaRepo.updateCuenta(cuenta);
      }
      // Usamos Future.microtask para evitar conflictos con mouse tracker
      Future.microtask(() {
        _loadCuentas(page: state.currentPage, searchQuery: state.searchQuery, sortOption: state.sortOption, showLoading: false);
      });
      return true;
    } catch (e) {
      rethrow;
    }
  }

  // MÉTODO QUE FALTABA
  Future<bool> deleteCuenta(Cuenta cuenta) async {
    if (cuenta.id == null) return false;
    try {
      await _cuentaRepo.deleteCuenta(cuenta.id!);
      // Usamos Future.microtask para evitar conflictos con mouse tracker
      Future.microtask(() {
        _loadCuentas(page: state.currentPage, searchQuery: state.searchQuery, sortOption: state.sortOption, showLoading: false);
      });
      return true;
    } catch (e) {
      print('[ERROR] deleteCuenta: $e');
      return false;
    }
  }

  // AHORA ESTE MÉTODO FUNCIONARÁ CORRECTAMENTE
  Future<void> search(String? query) async {
    print('[CUENTA_PROVIDER] search llamado con query: "$query"');
    // Almacenamos el query en el estado
    state = state.copyWith(searchQuery: query); 
    print('[CUENTA_PROVIDER] Estado actualizado con searchQuery: "${state.searchQuery}"');
    await _loadCuentas(page: 1, searchQuery: query); // Pasamos a la página 1
  }

  // Método para refrescar manualmente
  Future<void> refresh() async {
    print('[CUENTA_PROVIDER] refresh llamado');
    await _loadCuentas(page: state.currentPage, searchQuery: state.searchQuery, sortOption: state.sortOption, showLoading: true);
  }
  
  // Método para cambiar el ordenamiento
  Future<void> changeSortOption(CuentaSortOption sortOption) async {
    print('[CUENTA_PROVIDER] changeSortOption llamado con: $sortOption');
    state = state.copyWith(sortOption: sortOption);
    await _loadCuentas(page: 1, searchQuery: state.searchQuery, sortOption: sortOption, showLoading: true);
  }
  
  void _listenToChanges() {
    print('[CUENTA_PROVIDER] Activando listener de tiempo real...');
    final now = DateTime.now().millisecondsSinceEpoch;

    // Listener para la tabla 'cuentas'
    _cuentaChannel = Supabase.instance.client
        .channel('cuenta_provider_cuentas_$now')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'cuentas',
            callback: (payload) {
              print('[CUENTA_PROVIDER] Evento Realtime recibido en CUENTAS: $payload');
              Future.microtask(() {
                _loadCuentas(page: state.currentPage, searchQuery: state.searchQuery, sortOption: state.sortOption, showLoading: false);
              });
            })
        .subscribe();

    // Listener para la tabla 'proveedores'
    _proveedorChannel = Supabase.instance.client
        .channel('cuenta_provider_proveedores_$now') // Canal único
        .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'proveedores',
            callback: (payload) {
              print('[CUENTA_PROVIDER] Cambio detectado en PROVEEDORES, actualizando cuentas...');
              Future.microtask(() {
                _loadCuentas(page: state.currentPage, searchQuery: state.searchQuery, sortOption: state.sortOption, showLoading: false);
              });
            })
        .subscribe();

    print('[CUENTA_PROVIDER] Listeners de tiempo real configurados exitosamente');
    print('[CUENTA_PROVIDER] - Listener de cuentas: ${_cuentaChannel != null ? "ACTIVO" : "INACTIVO"}');
    print('[CUENTA_PROVIDER] - Listener de proveedores: ${_proveedorChannel != null ? "ACTIVO" : "INACTIVO"}');
  }

  @override
  void dispose() {
    _cuentaChannel?.unsubscribe();
    _proveedorChannel?.unsubscribe();
    super.dispose();
  }
}

// --- El Provider Final Modificado ---
final cuentasProvider = StateNotifierProvider.autoDispose<CuentasNotifier, CuentasState>((ref) {
  // Mantiene el provider vivo mientras tenga oyentes (como el VentasNotifier)
  // o hasta que la app se cierre.
  final link = ref.keepAlive();
  
  // Opcional: temporizador para cerrar el provider si no se usa
  // final timer = Timer(const Duration(seconds: 30), () {
  //   link.close();
  // });
  // ref.onDispose(() => timer.cancel());

  return CuentasNotifier(ref);
});