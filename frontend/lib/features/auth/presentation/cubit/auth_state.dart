import 'package:equatable/equatable.dart';
import '../../domain/models/usuario_perfil.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState extends Equatable {
  final AuthStatus status;
  final UsuarioPerfil? usuario;
  final String? errorMessage;
  final List<UsuarioPerfil> listaColaboradores;

  const AuthState({
    this.status = AuthStatus.initial,
    this.usuario,
    this.errorMessage,
    this.listaColaboradores = const [],
  });

  bool get isAuthenticated => status == AuthStatus.authenticated && usuario != null;
  bool get isAdmin => usuario?.isAdmin ?? false;
  bool get isRecepcao => usuario?.isRecepcao ?? false;
  bool get isAtendimento => usuario?.isAtendimento ?? false;

  AuthState copyWith({
    AuthStatus? status,
    UsuarioPerfil? usuario,
    String? errorMessage,
    List<UsuarioPerfil>? listaColaboradores,
    bool clearUsuario = false,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      usuario: clearUsuario ? null : (usuario ?? this.usuario),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      listaColaboradores: listaColaboradores ?? this.listaColaboradores,
    );
  }

  @override
  List<Object?> get props => [status, usuario, errorMessage, listaColaboradores];
}
