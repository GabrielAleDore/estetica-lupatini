class AppConstants {
  static const String appTitle = 'Estética Lupatini';
  static const String appSubtitle = 'Gestão Clínica & Fluxo Financeiro Híbrido';
  
  // Credenciais Oficiais Pré-Configuradas (Chave Pública Anon de Produção)
  static const String _defaultUrl = 'https://qfphiraxxyknhvqjcyrt.supabase.co';
  static const String _defaultAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFmcGhpcmF4eHlrbmh2cWpjeXJ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkzNDUxNjgsImV4cCI6MjEwNDkyMTE2OH0.H9fTwL_eddCQoSKJuBH8_yp-BEBt9_ve462yvtRSa58';

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
