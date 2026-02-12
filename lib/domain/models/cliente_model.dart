// ===== CÓDIGO CORRECTO PARA cliente_model.dart =====

class Cliente {
  final String? id;
  final String nombre;
  final String contacto;
  final String? nota;
  final DateTime? createdAt;
  final int ventasCount; // <--- La propiedad que falta

  // Propiedad calculada para el estado 'Activo/Inactivo'
  bool get esActivo => ventasCount > 0;

  Cliente({
    this.id,
    required this.nombre,
    required this.contacto,
    this.nota,
    this.createdAt,
    this.ventasCount = 0,
  });
  // ===== MÉTODO A AÑADIR =====
  Cliente copyWith({
    String? id,
    String? nombre,
    String? contacto,
    String? nota,
    DateTime? createdAt,
    int? ventasCount,
  }) {
    return Cliente(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      contacto: contacto ?? this.contacto,
      nota: nota ?? this.nota,
      createdAt: createdAt ?? this.createdAt,
      ventasCount: ventasCount ?? this.ventasCount,
    );
  }
  // ===== FIN DEL MÉTODO A AÑADIR =====
  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      id: json['id'],
      nombre: json['nombre'] ?? '',
      contacto: json['contacto'] ?? '',
      nota: json['nota'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      ventasCount: json['ventas_count'] ?? 0, // <--- La clave está aquí
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'nombre': nombre,
      'contacto': contacto,
      'nota': nota,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }
}