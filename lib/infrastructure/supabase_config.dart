import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = 'https://adutcsjrbjabdakogmge.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFkdXRjc2pyYmphYmRha29nbWdlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjYwODg1NDUsImV4cCI6MjA4MTY2NDU0NX0.M6ttRXAal_OLWUWcGvJVar6upCPaSB3Na-XAmHBscpg';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
