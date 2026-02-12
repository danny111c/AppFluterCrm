// lib/domain/models/transaccion_venta_model.dart

class TransaccionVenta {
  final String id;
  final String? ventaId;
  final String? clienteId;
  final String? clienteNombre;
  final String? clienteContacto;
  final String? perfil;
  final String? cuentaId;
  final DateTime fechaTransaccion;
  final double montoTransaccion;
  final DateTime periodoInicioServicio;
  final DateTime periodoFinServicio;
  final String tipoRegistro;
  final DateTime createdAt;
  final String? cuentaCorreo;
  final String? plataformaNombre;

  TransaccionVenta({
    required this.id,
    this.ventaId,
    this.clienteId,
    this.clienteNombre,
    this.clienteContacto,
    this.perfil,
    this.cuentaId,
    required this.fechaTransaccion,
    required this.montoTransaccion,
    required this.periodoInicioServicio,
    required this.periodoFinServicio,
    required this.tipoRegistro,
    required this.createdAt,
    this.cuentaCorreo,
    this.plataformaNombre,
  });

  // ===== USA ESTE FACTORY A PRUEBA DE BALAS =====
  factory TransaccionVenta.fromJson(Map<String, dynamic> json) {
    // Función auxiliar para parsear fechas de forma segura
    DateTime _parseSecureDate(String? dateString) {
      if (dateString == null) return DateTime(1970);
      return DateTime.tryParse(dateString) ?? DateTime(1970);
    }

    return TransaccionVenta(
      // ===== CAMBIO CRÍTICO Y ÚNICO AQUÍ =====
      // Ahora lee 'historial_id' directamente, que es lo que devuelve la RPC
      id: json['historial_id'] as String,

      ventaId: json['venta_id'] as String?,
      clienteId: json['cliente_id'] as String?,
      clienteNombre: json['cliente_nombre'] as String?,
      clienteContacto: json['cliente_contacto'] as String?,
      perfil: json['perfil'] as String?,
      cuentaId: json['cuenta_id'] as String?,
      fechaTransaccion: _parseSecureDate(json['fecha_transaccion']),
      periodoInicioServicio: _parseSecureDate(json['periodo_inicio_servicio']),
      periodoFinServicio: _parseSecureDate(json['periodo_fin_servicio']),
      createdAt: _parseSecureDate(json['created_at']),
      montoTransaccion: (json['monto_transaccion'] as num?)?.toDouble() ?? 0.0,
      tipoRegistro: json['tipo_registro'] as String? ?? 'N/A',
      cuentaCorreo: json['cuenta_correo'] as String?,
      plataformaNombre: json['plataforma_nombre'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'venta_id': ventaId,
        'cliente_id': clienteId,
        'cliente_nombre': clienteNombre,
        'cliente_contacto': clienteContacto,
        'perfil': perfil,
        'cuenta_id': cuentaId,
        'fecha_transaccion': fechaTransaccion.toIso8601String(),
        'monto_transaccion': montoTransaccion,
        'periodo_inicio_servicio': periodoInicioServicio.toIso8601String(),
        'periodo_fin_servicio': periodoFinServicio.toIso8601String(),
        'tipo_registro': tipoRegistro,
        'created_at': createdAt.toIso8601String(),
        'cuenta_correo': cuentaCorreo,
        'plataforma_nombre': plataformaNombre,
      };

  TransaccionVenta copyWith({
    String? id,
    String? ventaId,
    String? clienteId,
    String? clienteNombre,
    String? clienteContacto,
    String? perfil,
    String? cuentaId,
    DateTime? fechaTransaccion,
    double? montoTransaccion,
    DateTime? periodoInicioServicio,
    DateTime? periodoFinServicio,
    String? tipoRegistro,
    DateTime? createdAt,
    String? cuentaCorreo,
    String? plataformaNombre,
  }) {
    return TransaccionVenta(
      id: id ?? this.id,
      ventaId: ventaId ?? this.ventaId,
      clienteId: clienteId ?? this.clienteId,
      clienteNombre: clienteNombre ?? this.clienteNombre,
      clienteContacto: clienteContacto ?? this.clienteContacto,
      perfil: perfil ?? this.perfil,
      cuentaId: cuentaId ?? this.cuentaId,
      fechaTransaccion: fechaTransaccion ?? this.fechaTransaccion,
      montoTransaccion: montoTransaccion ?? this.montoTransaccion,
      periodoInicioServicio: periodoInicioServicio ?? this.periodoInicioServicio,
      periodoFinServicio: periodoFinServicio ?? this.periodoFinServicio,
      tipoRegistro: tipoRegistro ?? this.tipoRegistro,
      createdAt: createdAt ?? this.createdAt,
      cuentaCorreo: cuentaCorreo ?? this.cuentaCorreo,
      plataformaNombre: plataformaNombre ?? this.plataformaNombre,
    );
  }
}