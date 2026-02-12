class Proveedor {
  final String? id; // <-- CAMBIO 1: De int? a String?
  final String nombre;
  final String contacto; 
  final String? nota;
  final bool esActivo;
  final int cuentasCount; // Nuevo campo para conteo de cuentas
  final DateTime? deletedAt;

  Proveedor({
    this.id,
    required this.nombre,
    required this.contacto,
    this.nota,
    this.esActivo = false,
    this.cuentasCount = 0,
    this.deletedAt,
  });

  factory Proveedor.fromJson(Map<String, dynamic> json) {
    // Obtener el conteo de cuentas desde la RPC o desde el campo cuentas
    int cuentasCount = 0;
    bool activo = false;
    
    if (json.containsKey('cuentas_count')) {
      // Desde la función RPC
      cuentasCount = json['cuentas_count'] ?? 0;
      activo = cuentasCount > 0;
    } else {
      // Desde el método anterior (compatibilidad)
      final List<dynamic> cuentasData = json['cuentas'] ?? [];
      if (cuentasData.isNotEmpty) {
        cuentasCount = cuentasData[0]['count'] ?? 0;
        activo = cuentasCount > 0;
      }
    }

    return Proveedor(
      id: json['id'], // Lee el UUID como String
      nombre: json['nombre'],
      contacto: json['contacto'].toString(),
      nota: json['nota'],
      esActivo: activo,
      cuentasCount: cuentasCount,
      deletedAt: json['deleted_at'] != null 
          ? DateTime.parse(json['deleted_at']) 
          : null,
    );
  }

  // toJson corregido para no enviar el 'id' si es nulo.
  Map<String, dynamic> toJson() {
    final map = {
      'nombre': nombre,
      'contacto': contacto,
      'nota': nota,
      'deleted_at': deletedAt?.toIso8601String(),
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }
  
  // toMap para display no necesita cambiar.
  Map<String, dynamic> toMap() => {
    'Nombre': nombre,
    'Contacto': contacto,
    'Nota': nota ?? '',
    'id': id,
  };
   
  Proveedor copyWith({
    String? id, // <-- CAMBIO: De int? a String?
    String? nombre,
    String? contacto,
    String? nota,
    bool? esActivo,
    int? cuentasCount,
    DateTime? deletedAt,
  }) {
    return Proveedor(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      contacto: contacto ?? this.contacto,
      nota: nota ?? this.nota,
      esActivo: esActivo ?? this.esActivo,
      cuentasCount: cuentasCount ?? this.cuentasCount,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}