class AppConstants {
  static const String appTitle = 'Estética Lupatini';
  static const String appSubtitle = 'Gestão Clínica & Fluxo Financeiro Híbrido';
  
  // Credenciais Oficiais Pré-Configuradas (Fallback Inteligente de Produção)
  static const String _defaultUrl = 'https://qfphiraxxyknhvqjcyrt.supabase.co';
  static const String _defaultAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFmcGhpcmF4eHlrbmh2cWpjeXJ0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4OTM0NTE2OCwiZXhwIjoyMTA0OTIxMTY4fQ.345MI-B4CjjjJpSQkfxwD5931E_Uk9KoD8UgQuue768';

  // Suporte flexível a --dart-define=SUPABASE_URL=...
  static const String _envUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  // Suporte flexível a --dart-define=SUPABASE_ANON_KEY=... ou --dart-define=SUPABASE_KEY=...
  static const String _envAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  static const String _envKey = String.fromEnvironment('SUPABASE_KEY', defaultValue: '');

  static String get supabaseUrl => _envUrl.isNotEmpty ? _envUrl : _defaultUrl;
  
  static String get supabaseAnonKey {
    if (_envAnonKey.isNotEmpty) return _envAnonKey;
    if (_envKey.isNotEmpty) return _envKey;
    return _defaultAnonKey;
  }
  
  // Breakpoints Responsivos (px)
  static const double mobileBreakpoint = 650.0;
  static const double tabletBreakpoint = 1024.0;
}
