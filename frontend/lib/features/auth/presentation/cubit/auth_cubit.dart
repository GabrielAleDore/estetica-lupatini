import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/auth_repository.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repository;

  AuthCubit({AuthRepository? repository})
      : _repository = repository ?? AuthRepository(),
        super(const AuthState());

  Future<void> verificarSessaoInicial() async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      final usuario = await _repository.obterUsuarioAtual();
      if (usuario != null && usuario.ativo) {
        emit(state.copyWith(
          status: AuthStatus.authenticated,
          usuario: usuario,
          clearError: true,
        ));
      } else {
        emit(state.copyWith(
          status: AuthStatus.unauthenticated,
          clearUsuario: true,
        ));
      }
    } catch (_) {
      emit(state.copyWith(
        status: AuthStatus.unauthenticated,
        clearUsuario: true,
      ));
    }
  }

  Future<bool> login({required String email, required String password}) async {
    emit(state.copyWith(status: AuthStatus.loading, clearError: true));
    try {
      final usuario = await _repository.signIn(email: email, password: password);
      emit(state.copyWith(
        status: AuthStatus.authenticated,
        usuario: usuario,
        clearError: true,
      ));
      return true;
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      ));
      return false;
    }
  }

  Future<void> logout() async {
    await _repository.signOut();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('lembrar_email_lupatini');
      await prefs.setBool('lembrar_acesso_lupatini', false);
    } catch (_) {}
    emit(state.copyWith(
      status: AuthStatus.unauthenticated,
      clearUsuario: true,
      clearError: true,
    ));
  }

  Future<void> carregarColaboradores() async {
    try {
      final lista = await _repository.listarUsuarios();
      emit(state.copyWith(listaColaboradores: lista));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<bool> cadastrarNovoUsuario({
    required String nome,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      await _repository.criarUsuarioAdmin(
        nome: nome,
        email: email,
        password: password,
        role: role,
      );
      await carregarColaboradores();
      return true;
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString().replaceAll('Exception: ', '')));
      return false;
    }
  }

  Future<void> alternarStatusUsuario(String id, bool ativoAtual) async {
    try {
      await _repository.atualizarStatusUsuario(id, !ativoAtual);
      await carregarColaboradores();
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<bool> excluirUsuario(String id) async {
    try {
      await _repository.excluirUsuario(id);
      await carregarColaboradores();
      return true;
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString().replaceAll('Exception: ', '')));
      return false;
    }
  }
}
