// lib/domain/models/plantilla_model.dart (VERSIÓN FINAL Y CORRECTA)

import 'package:equatable/equatable.dart';

class Plantilla extends Equatable {
  final String? id;
  final String nombre;
  final String contenido;
  final String tipo; 
  final List<String> visibilidad; // ✅ NUEVO CAMPO

  const Plantilla({
    this.id,
    required this.nombre,
    required this.contenido,
    required this.tipo,
    this.visibilidad = const [], // ✅ Por defecto vacía
  });

  factory Plantilla.fromJson(Map<String, dynamic> json) {
    return Plantilla(
      id: json['id'],
      nombre: json['nombre'] as String,
      contenido: json['contenido'] as String,
      tipo: json['tipo'] as String,
      // ✅ Cargamos la lista desde la DB
      visibilidad: List<String>.from(json['visibilidad'] ?? []), 
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'nombre': nombre,
      'contenido': contenido,
      'tipo': tipo,
      'visibilidad': visibilidad, // ✅ Guardamos la lista
    };
    if (id != null && !id!.startsWith('temp_')) {
      map['id'] = id!;
    }
    return map;
  }
 
  Plantilla copyWith({
    String? id,
    String? nombre,
    String? contenido,
    String? tipo,
    List<String>? visibilidad, // ✅ Añadido al copyWith
  }) {
    return Plantilla(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      contenido: contenido ?? this.contenido,
      tipo: tipo ?? this.tipo,
      visibilidad: visibilidad ?? this.visibilidad,
    );
  }

  @override
  List<Object?> get props => [id, nombre, contenido, tipo, visibilidad];
}