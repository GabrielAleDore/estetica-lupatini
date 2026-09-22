import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';

/// Serviço unificado de injeção e acesso ao cliente oficial Supabase.
class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: AppConstants.supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: AppConstants.supabaseAnonKey,
        realtimeClientOptions: const RealtimeClientOptions(
          eventsPerSecond: 10,
        ),
      );
      debugPrint('Supabase inicializado com sucesso em: ${AppConstants.supabaseUrl}');
    } catch (e) {
      debugPrint('Aviso: Falha na inicialização do Supabase: $e');
    }
  }
}
