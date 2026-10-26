import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/contas_bancarias_repository.dart';
import '../../domain/models/conta_bancaria_model.dart';
import 'contas_bancarias_state.dart';

class ContasBancariasCubit extends Cubit<ContasBancariasState> {
  final ContasBancariasRepository _repository;
  StreamSubscription? _streamSubscription;

  ContasBancariasCubit({ContasBancariasRepository? repository})
      : _repository = repository ?? ContasBancariasRepository(),
        super(const ContasBancariasState()) {
    _iniciarEscutaRealtime();
  }

  void _iniciarEscutaRealtime() {
    try {
      _streamSubscription = _repository.streamContas().listen((_) {
        // Atualiza a lista e saldos de forma silenciosa e reativa
        carregarContas(silencioso: true);
      }, onError: (_) {});
    } catch (_) {}
  }

  /// Carrega a lista completa de contas bancárias
  Future<void> carregarContas({bool silencioso = false}) async {
    if (!silencioso) {
      emit(state.copyWith(status: ContasBancariasStatus.loading, clearMessages: true));
    }
    try {
      final contas = await _repository.getContas();
      emit(state.copyWith(
        status: ContasBancariasStatus.success,
        contas: contas,
      ));
    } catch (e) {
      if (!silencioso) {
        emit(state.copyWith(
          status: ContasBancariasStatus.error,
          errorMessage: 'Não foi possível carregar as contas bancárias: $e',
        ));
      }
    }
  }

  /// Altera o filtro de visualização por escopo ('TODOS', 'PJ', 'PF')
  void mudarFiltroEscopo(String escopo) {
    emit(state.copyWith(filtroEscopo: escopo, clearMessages: true));
  }

  /// Alterna exibição apenas de contas ativas
  void alternarApenasAtivas(bool apenasAtivas) {
    emit(state.copyWith(apenasAtivas: apenasAtivas, clearMessages: true));
  }

  /// Cria uma nova conta bancária
  Future<bool> criarConta(ContaBancariaModel conta) async {
    emit(state.copyWith(status: ContasBancariasStatus.loading, clearMessages: true));
    try {
      final novaConta = await _repository.createConta(conta);
      final novasContas = [...state.contas, novaConta];
      emit(state.copyWith(
        status: ContasBancariasStatus.success,
        contas: novasContas,
        successMessage: 'Conta bancária "${novaConta.nomeConta}" criada com sucesso!',
      ));
      return true;
    } catch (e) {
      emit(state.copyWith(
        status: ContasBancariasStatus.error,
        errorMessage: 'Erro ao cadastrar conta bancária: $e',
      ));
      return false;
    }
  }

  /// Atualiza os dados de uma conta existente
  Future<bool> atualizarConta(ContaBancariaModel conta) async {
    emit(state.copyWith(status: ContasBancariasStatus.loading, clearMessages: true));
    try {
      final contaAtualizada = await _repository.updateConta(conta);
      final novasContas = state.contas.map((c) {
        return c.id == contaAtualizada.id ? contaAtualizada : c;
      }).toList();

      emit(state.copyWith(
        status: ContasBancariasStatus.success,
        contas: novasContas,
        successMessage: 'Conta "${contaAtualizada.nomeConta}" atualizada com sucesso!',
      ));
      return true;
    } catch (e) {
      emit(state.copyWith(
        status: ContasBancariasStatus.error,
        errorMessage: 'Erro ao atualizar conta bancária: $e',
      ));
      return false;
    }
  }

  /// Inativa ou ativa a conta bancária
  Future<bool> alternarStatus(String id, bool novoStatus) async {
    try {
      await _repository.toggleAtivo(id, novoStatus);
      final novasContas = state.contas.map((c) {
        return c.id == id ? c.copyWith(ativo: novoStatus) : c;
      }).toList();

      final acao = novoStatus ? 'ativada' : 'inativada';
      emit(state.copyWith(
        status: ContasBancariasStatus.success,
        contas: novasContas,
        successMessage: 'Conta bancária $acao com sucesso!',
      ));
      return true;
    } catch (e) {
      emit(state.copyWith(
        status: ContasBancariasStatus.error,
        errorMessage: 'Erro ao alterar status da conta bancária: $e',
      ));
      return false;
    }
  }

  /// Remove ou inativa definitivamente a conta bancária
  Future<bool> excluirConta(String id) async {
    try {
      await _repository.deleteOuInativarConta(id, deleteDefinitivo: true);
      final novasContas = state.contas.where((c) => c.id != id).toList();
      emit(state.copyWith(
        status: ContasBancariasStatus.success,
        contas: novasContas,
        successMessage: 'Conta bancária excluída com sucesso!',
      ));
      return true;
    } catch (e) {
      emit(state.copyWith(
        status: ContasBancariasStatus.error,
        errorMessage: 'Erro ao excluir conta bancária: $e',
      ));
      return false;
    }
  }

  /// Recalcula e reconcilia o saldo atual da conta bancária no banco de dados com base nas transações
  Future<bool> reconciliarSaldo(String id) async {
    emit(state.copyWith(status: ContasBancariasStatus.loading, clearMessages: true));
    try {
      await _repository.reconciliarSaldo(id);
      await carregarContas();
      emit(state.copyWith(
        status: ContasBancariasStatus.success,
        successMessage: 'Saldo reconciliado com sucesso com base no histórico de transações!',
      ));
      return true;
    } catch (e) {
      emit(state.copyWith(
        status: ContasBancariasStatus.error,
        errorMessage: 'Erro ao reconciliar saldo da conta bancária: $e',
      ));
      return false;
    }
  }

  @override
  Future<void> close() {
    _streamSubscription?.cancel();
    return super.close();
  }
}
