import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/estoque_repository.dart';
import 'estoque_state.dart';

class EstoqueCubit extends Cubit<EstoqueState> {
  final EstoqueRepository _repository;
  StreamSubscription? _subMovimentacoes;

  EstoqueCubit({EstoqueRepository? repository})
      : _repository = repository ?? EstoqueRepository(),
        super(const EstoqueState()) {
    carregarDados();
    _iniciarEscutaRealtime();
  }

  void _iniciarEscutaRealtime() {
    _subMovimentacoes?.cancel();
    _subMovimentacoes = _repository.streamMovimentacoes().listen(
      (_) {
        // Recarrega silenciosamente quando houver nova venda ou movimentação
        recarregarSilencioso();
      },
      onError: (_) {},
    );
  }

  Future<void> carregarDados() async {
    emit(state.copyWith(status: EstoqueStatus.loading));
    try {
      final prods = await _repository.obterProdutos();
      final movs = await _repository.obterMovimentacoes();

      emit(state.copyWith(
        status: EstoqueStatus.success,
        produtos: prods,
        movimentacoes: movs,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: EstoqueStatus.error,
        mensagemErro: e.toString().replaceAll('Exception: ', ''),
      ));
    }
  }

  Future<void> recarregarSilencioso() async {
    try {
      final prods = await _repository.obterProdutos();
      final movs = await _repository.obterMovimentacoes();

      emit(state.copyWith(
        produtos: prods,
        movimentacoes: movs,
      ));
    } catch (_) {}
  }

  void mudarFiltroTipo(String tipo) {
    emit(state.copyWith(filtroTipo: tipo));
  }

  void mudarFiltroProduto(String? produtoId) {
    if (produtoId == null || produtoId.isEmpty || produtoId == 'TODOS') {
      emit(state.copyWith(clearFiltroProduto: true));
    } else {
      emit(state.copyWith(filtroProdutoId: produtoId));
    }
  }

  void mudarFiltroBusca(String busca) {
    emit(state.copyWith(filtroBusca: busca));
  }

  void mudarFiltroPeriodo(String periodo) {
    emit(state.copyWith(filtroPeriodo: periodo));
  }

  Future<bool> registrarEntrada({
    required String produtoId,
    required double quantidade,
    double? custoUnitario,
    String? motivo,
    DateTime? dataLancamento,
  }) async {
    try {
      await _repository.registrarEntrada(
        produtoId: produtoId,
        quantidade: quantidade,
        custoUnitario: custoUnitario,
        motivo: motivo,
        dataLancamento: dataLancamento,
      );
      await carregarDados();
      return true;
    } catch (e) {
      emit(state.copyWith(
        mensagemErro: e.toString().replaceAll('Exception: ', ''),
      ));
      return false;
    }
  }

  Future<bool> registrarSaida({
    required String produtoId,
    required double quantidade,
    required String motivo,
    String tipo = 'SAIDA',
    DateTime? dataLancamento,
  }) async {
    try {
      await _repository.registrarSaida(
        produtoId: produtoId,
        quantidade: quantidade,
        motivo: motivo,
        tipo: tipo,
        dataLancamento: dataLancamento,
      );
      await carregarDados();
      return true;
    } catch (e) {
      emit(state.copyWith(
        mensagemErro: e.toString().replaceAll('Exception: ', ''),
      ));
      return false;
    }
  }

  @override
  Future<void> close() {
    _subMovimentacoes?.cancel();
    return super.close();
  }
}
