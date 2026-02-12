import 'package:intl/intl.dart';

class TransaccionCuenta {
  final String id;
  final DateTime createdAt;
  final String cuentaId;
  final double monto;
  final DateTime periodoInicio;
  final DateTime periodoFin;
  final String tipoRegistro;
  final String cuentaCorreo;
  final String proveedorNombre;
  final String proveedorContacto;
  final String plataformaNombre;
  final String? numeroProveedor; // Asegúrate de que este campo esté definido
  final String? plataforma; // Asegúrate de que este campo esté definido

  TransaccionCuenta({
    required this.id,
    required this.createdAt,
    required this.cuentaId,
    required this.monto,
    required this.periodoInicio,
    required this.periodoFin,
    required this.tipoRegistro,
    required this.cuentaCorreo,
    required this.proveedorNombre,
    required this.proveedorContacto,
    required this.plataformaNombre,
    this.numeroProveedor,
    this.plataforma,
  });

  factory TransaccionCuenta.fromJson(Map<String, dynamic> json) {
    return TransaccionCuenta(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      cuentaId: json['cuenta_id'] as String,
      monto: (json['monto_gastado'] as num).toDouble(),
      periodoInicio: DateTime.parse(json['periodo_inicio'] as String),
      periodoFin: DateTime.parse(json['periodo_fin'] as String),
      tipoRegistro: json['tipo_registro'] as String,
      cuentaCorreo: json['cuenta_correo'] as String,
      proveedorNombre: json['proveedor_nombre'] as String,
      proveedorContacto: json['proveedor_contacto'] as String,
      plataformaNombre: json['plataforma_nombre'] as String,
      numeroProveedor: json['numero_proveedor'] as String?, // Asegúrate de que este campo esté en el JSON
      plataforma: json['plataforma'] as String?, // Asegúrate de que este campo esté en el JSON
    );
  }
}