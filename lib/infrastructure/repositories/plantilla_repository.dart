// lib/infrastructure/repositories/plantilla_repository.dart (NUEVO ARCHIVO)

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/plantilla_model.dart';
import '../supabase_config.dart';

class PlantillaRepository {
  final SupabaseClient _supabase = SupabaseConfig.client;

  

  // Obtiene todas las plantillas, ordenadas por nombre
  Future<List<Plantilla>> getPlantillas() async {
    try {
      final response = await _supabase
          .from('plantillas')
          .select()
          .order('nombre', ascending: true);
      return response.map((data) => Plantilla.fromJson(data)).toList();
    } catch (e) {
      print('[ERROR] getPlantillas: $e');
      rethrow;
    }
  }

  // Añade una nueva plantilla
  Future<Plantilla> addPlantilla(Plantilla plantilla) async {
    try {
      final response = await _supabase
          .from('plantillas')
          .insert(plantilla.toJson())
          .select() // Pide que devuelva el registro insertado
          .single(); // Espera un solo resultado
      return Plantilla.fromJson(response); // Devuelve el objeto completo
    } catch (e) {
      print('[ERROR] addPlantilla: $e');
      rethrow;
    }
  }

  Future<void> updatePlantilla(Plantilla plantilla) async {
    try {
      await _supabase.from('plantillas').update(plantilla.toJson()).eq('id', plantilla.id!);
    } catch (e) { rethrow; }
  }

  Future<void> deletePlantilla(String id) async {
    try {
      await _supabase.from('plantillas').delete().eq('id', id);
    } catch (e) { rethrow; }
  }
}
