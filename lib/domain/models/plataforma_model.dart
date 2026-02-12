import 'package:equatable/equatable.dart';

class Plataforma extends Equatable {
  final String? id;
  final String nombre;
  final String? nota;
  final DateTime? deletedAt;
  final DateTime? createdAt;
  final int? totalCount;   // Para paginación (total de la lista)
  final int? cuentasCount; // ✅ Para validación (cuentas vinculadas)

  const Plataforma({
    this.id,
    required this.nombre,
    this.nota,
    this.deletedAt,
    this.createdAt,
    this.totalCount,
    this.cuentasCount,
  });

  factory Plataforma.fromJson(Map<String, dynamic> json) {
    return Plataforma(
      id: json['id'],
      nombre: json['nombre'],
      nota: json['nota'],
      // tryParse porque ahora el SQL los manda como texto para evitar errores
      deletedAt: json['deleted_at'] != null ? DateTime.tryParse(json['deleted_at'].toString()) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      totalCount: json['total_count'] != null ? int.tryParse(json['total_count'].toString()) : 0,
      cuentasCount: json['cuentas_count'] != null ? int.tryParse(json['cuentas_count'].toString()) : 0,
    );
  }

  Map<String, dynamic> toJsonDb() {
    return {
      'nombre': nombre,
      'nota': nota ?? '',
    };
  }

  Plataforma copyWith({
    String? id,
    String? nombre,
    String? nota,
    DateTime? deletedAt,
    DateTime? createdAt,
    int? totalCount,
    int? cuentasCount,
  }) {
    return Plataforma(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      nota: nota ?? this.nota,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      totalCount: totalCount ?? this.totalCount,
      cuentasCount: cuentasCount ?? this.cuentasCount,
    );
  }

  @override
  List<Object?> get props => [id, nombre, nota, deletedAt, createdAt, totalCount, cuentasCount];
}