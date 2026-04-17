import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = 'https://wghwaxnukabganzpsqlu.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndnaHdheG51a2FiZ2FuenBzcWx1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ2NzgwMjIsImV4cCI6MjA5MDI1NDAyMn0.BZ6B5OcRfmLMFXXgu5hP2XPo1d0QYRK_imN_A-I-iHI';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      debug: true,
    );
  }
}