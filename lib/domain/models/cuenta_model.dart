import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';
import 'plataforma_model.dart';
import 'proveedor_model.dart';
import 'tipo_cuenta_model.dart';

class Cuenta extends Equatable {
  final String? id;
  final Plataforma plataforma;
  final TipoCuenta tipoCuenta;
  final Proveedor proveedor;
  final String correo;
  final String contrasena;
  final int numPerfiles;
  final int perfilesDisponibles;
  final String? problemaCuenta;
  final DateTime? fechaReporteCuenta;
  final double? costoCompra;
  final String? fechaInicio;
  final String? fechaFinal;
  final String? nota;
  final int? diasServicio;
  final DateTime? deletedAt;
  final bool isPaused;
  final DateTime? fechaPausa;
  final String? prioridadActual;
  final bool tieneCascada; // ✅ NUEVA PROPIEDAD

  const Cuenta({
    this.id,
    required this.plataforma,
    required this.tipoCuenta,
    required this.proveedor,
    required this.correo,
    required this.contrasena,
    required this.numPerfiles,
    required this.perfilesDisponibles,
    this.problemaCuenta,
    this.fechaReporteCuenta,
    this.costoCompra,
    this.fechaInicio,
    this.fechaFinal,
    this.nota,
    this.diasServicio,
    this.deletedAt,
    this.isPaused = false,
    this.fechaPausa,
    this.prioridadActual,
    this.tieneCascada = false, // ✅ INICIALIZAR
  });

  int get diasRestantes {
    if (fechaFinal == null) return 0;
    try {
      final fechaFinalDate = DateFormat('yyyy-MM-dd').parse(fechaFinal!);
      final ahora = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final diferencia = fechaFinalDate.difference(ahora);
      return diferencia.inDays < 0 ? 0 : diferencia.inDays;
    } catch (e) {
      return 0;
    }
  }

  factory Cuenta.fromJson(Map<String, dynamic> json) {
    // Detectar si viene de RPC o tabla normal
    final bool isRpcData = json.containsKey('tiene_cascada'); 

    // Lógica común de mapeo
    return Cuenta(
      id: json['id'],
      plataforma: isRpcData 
          ? Plataforma(id: json['plataforma_id'] ?? '', nombre: json['plataforma_nombre'] ?? 'N/A')
          : Plataforma.fromJson(json['plataformas']),
      tipoCuenta: isRpcData
          ? TipoCuenta(id: json['tipo_cuenta_id'], nombre: json['tipo_cuenta_nombre'] ?? 'N/A')
          : TipoCuenta.fromJson(json['tipos_cuenta']),
      proveedor: isRpcData
          ? Proveedor(id: json['proveedor_id'], nombre: json['proveedor_nombre'] ?? 'N/A', contacto: json['proveedor_contacto'] ?? 'N/A')
          : Proveedor.fromJson(json['proveedores']),
      correo: json['email'] ?? json['correo'] ?? '',
      contrasena: json['password'] ?? json['contrasena'] ?? '',
      numPerfiles: json['num_perfiles'] ?? 1,
      perfilesDisponibles: json['perfiles_disponibles'] ?? json['num_perfiles'] ?? 1,
      problemaCuenta: json['problema_cuenta'],
      fechaReporteCuenta: json['fecha_reporte_cuenta'] != null ? DateTime.parse(json['fecha_reporte_cuenta']) : null,
      costoCompra: (json['costo_compra'] as num?)?.toDouble(),
      fechaInicio: json['fecha_inicio'],
      fechaFinal: json['fecha_final'],
      nota: json['nota'],
      deletedAt: json['deleted_at'] != null ? DateTime.parse(json['deleted_at']) : null,
      isPaused: json['is_paused'] ?? false,
      fechaPausa: json['fecha_pausa'] != null ? DateTime.parse(json['fecha_pausa']) : null,
      prioridadActual: json['prioridad_actual']?.toString(),
      tieneCascada: json['tiene_cascada'] ?? false, // ✅ LEER DE LA DB
    );
  }

  Map<String, dynamic> toJson() {
    final map = {
      'plataforma_id': plataforma.id,
      'tipo_cuenta_id': tipoCuenta.id,
      'proveedor_id': proveedor.id,
      'correo': correo,
      'contrasena': contrasena,
      'num_perfiles': numPerfiles,
      'perfiles_disponibles': perfilesDisponibles,
      'problema_cuenta': problemaCuenta,
      'fecha_reporte_cuenta': fechaReporteCuenta?.toIso8601String(),
      'costo_compra': costoCompra,
      'fecha_inicio': fechaInicio,
      'fecha_final': fechaFinal,
      'nota': nota,
      'deleted_at': deletedAt?.toIso8601String(),
      'is_paused': isPaused,
      'fecha_pausa': fechaPausa?.toIso8601String(),
      'prioridad_actual': prioridadActual,
      // No enviamos tieneCascada porque es un campo calculado, no guardado en la tabla cuentas
    };
    if (id != null) map['id'] = id;
    return map;
  }

  @override
  List<Object?> get props => [
    id, plataforma, tipoCuenta, proveedor, correo, contrasena, numPerfiles, perfilesDisponibles,
    problemaCuenta, fechaReporteCuenta, costoCompra, fechaInicio, fechaFinal, nota, diasServicio, deletedAt,
    isPaused, fechaPausa, prioridadActual, tieneCascada // ✅ Añadido
  ];

  Cuenta copyWith({
    String? id, Plataforma? plataforma, TipoCuenta? tipoCuenta, Proveedor? proveedor,
    String? correo, String? contrasena, int? numPerfiles, int? perfilesDisponibles,
    String? problemaCuenta, DateTime? fechaReporteCuenta, bool setProblemaToNull = false,
    double? costoCompra, String? fechaInicio, String? fechaFinal, String? nota,
    int? diasServicio, DateTime? deletedAt, bool? isPaused, DateTime? fechaPausa,
    String? prioridadActual, bool? tieneCascada, // ✅ Añadido
  }) {
    return Cuenta(
      id: id ?? this.id,
      plataforma: plataforma ?? this.plataforma,
      tipoCuenta: tipoCuenta ?? this.tipoCuenta,
      proveedor: proveedor ?? this.proveedor,
      correo: correo ?? this.correo,
      contrasena: contrasena ?? this.contrasena,
      numPerfiles: numPerfiles ?? this.numPerfiles,
      perfilesDisponibles: perfilesDisponibles ?? this.perfilesDisponibles,
      problemaCuenta: setProblemaToNull ? null : (problemaCuenta ?? this.problemaCuenta),
      fechaReporteCuenta: setProblemaToNull ? null : (fechaReporteCuenta ?? this.fechaReporteCuenta),
      costoCompra: costoCompra ?? this.costoCompra,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaFinal: fechaFinal ?? this.fechaFinal,
      nota: nota ?? this.nota,
      diasServicio: diasServicio ?? this.diasServicio,
      deletedAt: deletedAt ?? this.deletedAt,
      isPaused: isPaused ?? this.isPaused,
      fechaPausa: fechaPausa ?? this.fechaPausa,
      prioridadActual: prioridadActual ?? this.prioridadActual,
      tieneCascada: tieneCascada ?? this.tieneCascada, // ✅ Añadido
    );
  }
}