// domain/models/venta_model.dart

import 'package:equatable/equatable.dart';
import 'cliente_model.dart';
import 'cuenta_model.dart';
import 'plataforma_model.dart';
import 'proveedor_model.dart';
import 'tipo_cuenta_model.dart';

class Venta extends Equatable {
  final String? id;
  final Cliente cliente;
  final Cuenta cuenta;
  final String? perfilId; // ✅ 1. NUEVA PROPIEDAD AÑADIDA
  final String? perfilAsignado; 
  final String? pin;
  final double precio;
  final String fechaInicio;
  final String fechaFinal;
  final String? nota;
  final String? problemaVenta;
  final DateTime? fechaReporteVenta;
  final DateTime? createdAt; 
  final DateTime? deletedAt;

  // ✅ 2. CONSTRUCTOR ACTUALIZADO CON perfilId
  const Venta({
    this.id,
    required this.cliente,
    required this.cuenta,
    this.perfilId, // <--- Añadido aquí
    this.perfilAsignado, 
    this.pin,
    required this.precio,
    required this.fechaInicio,
    required this.fechaFinal,
    this.nota,
    this.problemaVenta,
    this.fechaReporteVenta,
    this.createdAt, 
    this.deletedAt,
  });

  int get diasRestantes {
    try {
      final fechaFinalDate = DateTime.parse(fechaFinal);
      final ahora = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final diferencia = fechaFinalDate.difference(ahora);
      return diferencia.inDays < 0 ? 0 : diferencia.inDays;
    } catch (e) {
      return 0;
    }
  }

  // =========================================================================
  // ===================== FACTORY FROMJSON ACTUALIZADO ======================
  // =========================================================================
factory Venta.fromJson(Map<String, dynamic> json) {
    try {
      // Log de depuración para ver qué llega
      // print('DEBUG-MODEL: Mapeando venta ID ${json['id']}');

      return Venta(
        id: json['id']?.toString(),
        cliente: Cliente(
          id: json['cliente_id']?.toString(),
          nombre: json['cliente_nombre']?.toString() ?? 'N/A',
          contacto: json['cliente_contacto']?.toString() ?? '',
        ),
        cuenta: Cuenta(
          id: json['cuenta_id']?.toString(),
          correo: json['cuenta_correo']?.toString() ?? '',
          contrasena: json['cuenta_contrasena']?.toString() ?? '',
          plataforma: Plataforma(id: null, nombre: json['plataforma_nombre'] ?? ''),
          tipoCuenta: TipoCuenta(id: null, nombre: json['tipo_cuenta_nombre'] ?? ''),
          proveedor: Proveedor(id: null, nombre: json['proveedor_nombre'] ?? '', contacto: ''),
          numPerfiles: 0,
          perfilesDisponibles: 0,
          problemaCuenta: json['cuenta_problema'],
        ),
        perfilId: json['perfil_id']?.toString(), // CAPTURAMOS EL NUEVO VÍNCULO
        perfilAsignado: json['perfil_asignado']?.toString(),
        pin: json['pin_perfil']?.toString(),
        precio: (json['precio'] as num? ?? 0.0).toDouble(),
        fechaInicio: json['fecha_inicio']?.toString() ?? '',
        fechaFinal: json['fecha_final']?.toString() ?? '',
        nota: json['nota']?.toString(),
        problemaVenta: json['problema_venta']?.toString(),
fechaReporteVenta: json['fecha_reporte_venta'] != null
    ? DateTime.tryParse(json['fecha_reporte_venta'].toString())
    : null,
createdAt: json['created_at'] != null
    ? DateTime.tryParse(json['created_at'].toString())
    : null,
deletedAt: json['deleted_at'] != null
    ? DateTime.tryParse(json['deleted_at'].toString())
    : null,
      );
    } catch (e, stack) {
      print('🚨 [VENTA_MODEL] Error de casteo en fromJson: $e');
      print('Datos del JSON problemático: $json');
      rethrow;
    }
  }

  // =========================================================================
  // ======================= TOJSON ACTUALIZADO ==============================
  // =========================================================================
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'cliente_id': cliente.id,
      'cuenta_id': cuenta.id,
      'perfil_id': perfilId, // ✅ 4. ENVÍA EL perfil_id A SUPABASE
      'perfil_asignado': perfilAsignado,
      'pin_perfil': pin,
      'precio': precio,
      'fecha_inicio': fechaInicio,
      'fecha_final': fechaFinal,
      'nota': nota,
      'problema_venta': problemaVenta,
      'fecha_reporte_venta': fechaReporteVenta?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };

    if (createdAt != null) {
      map['created_at'] = createdAt!.toIso8601String();
    }
    
    return map;
  }

  @override
  List<Object?> get props => [
    id,
    cliente,
    cuenta,
    perfilId, // ✅ 5. AÑADIDO A PROPS
    perfilAsignado,
    pin,
    precio,
    fechaInicio,
    fechaFinal,
    nota,
    problemaVenta,
    fechaReporteVenta,
    createdAt, 
    deletedAt,
  ];

  // =========================================================================
  // ======================= COPYWITH ACTUALIZADO ============================
  // =========================================================================
  Venta copyWith({
    String? id,
    Cliente? cliente,
    Cuenta? cuenta,
    String? perfilId, // ✅ 6. PARÁMETRO AÑADIDO
    String? perfilAsignado,
    String? pin,
    double? precio,
    String? fechaInicio,
    String? fechaFinal,
    String? nota,
    String? problemaVenta,
    DateTime? fechaReporteVenta,
    DateTime? createdAt, 
    DateTime? deletedAt,
    bool setProblemaToNull = false,
  }) {
    return Venta(
      id: id ?? this.id,
      cliente: cliente ?? this.cliente,
      cuenta: cuenta ?? this.cuenta,
      perfilId: perfilId ?? this.perfilId, // <--- Aplicado aquí
      perfilAsignado: perfilAsignado ?? this.perfilAsignado,
      pin: pin ?? this.pin,
      precio: precio ?? this.precio,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaFinal: fechaFinal ?? this.fechaFinal,
      nota: nota ?? this.nota,
      problemaVenta: setProblemaToNull ? null : (problemaVenta ?? this.problemaVenta),
      fechaReporteVenta: setProblemaToNull ? null : (fechaReporteVenta ?? this.fechaReporteVenta),
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}