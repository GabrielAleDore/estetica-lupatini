import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/contas_pagar_repository.dart';
import 'contas_pagar_state.dart';

class ContasPagarCubit extends Cubit<ContasPagarState> {
  final ContasPagarRepository _repository;
  StreamSubscription? _streamSubscription;

  ContasPagarCubit({ContasPagarRepository? repository})
      : _repository = repository ?? ContasPagarRepository(),
        super(const ContasPagarState()) {
    _iniciarRealtime();
  }

  void _iniciarRealtime() {
    _streamSubscription?.cancel();
    _streamSubscription = _repository.streamTransacoes().listen((_) {
      carregarContas(silencioso: true);
    });
  }

  Future<void> carregarContas({bool silencioso = false}) async {
    if (!silencioso) {
      emit(state.copyWith(status: ContasPagarStatus.loading, clearMessages: true));
    }

    try {
      final contas = await _repository.listarContasPagar();
      final categorias = await _repository.listarCategoriasDespesa();

      emit(state.copyWith(
        status: ContasPagarStatus.loaded,
        contas: contas,
        categorias: categorias,
        clearMessages: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ContasPagarStatus.error,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      ));
    }
  }

  void mudarAba(String aba) {
    emit(state.copyWith(filtroAba: aba));
  }

  void mudarEscopo(String escopo) {
    emit(state.copyWith(filtroEscopo: escopo));
  }

  Future<bool> cadastrarDespesa(Map<String, dynamic> dados) async {
    try {
      await _repository.cadastrarContaPagar(dados);
      emit(state.copyWith(successMessage: 'Despesa lançada com sucesso!'));
      await carregarContas();
      return true;
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString().replaceAll('Exception: ', '')));
      return false;
    }
  }

  Future<bool> marcarComoPago(String transacaoId) async {
    try {
      await _repository.marcarComoPago(transacaoId);
      emit(state.copyWith(successMessage: 'Conta marcada como paga!'));
      await carregarContas();
      return true;
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString().replaceAll('Exception: ', '')));
      return false;
    }
  }

  Future<bool> excluirDespesa(String transacaoId) async {
    try {
      await _repository.excluirContaPagar(transacaoId);
      emit(state.copyWith(successMessage: 'Despesa excluída com sucesso!'));
      await carregarContas();
      return true;
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString().replaceAll('Exception: ', '')));
      return false;
    }
  }

  @override
  Future<void> close() {
    _streamSubscription?.cancel();
    return super.close();
  }
}
