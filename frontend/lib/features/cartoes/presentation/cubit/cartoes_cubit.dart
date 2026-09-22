import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/cartoes_repository.dart';
import 'cartoes_state.dart';

class CartoesCubit extends Cubit<CartoesState> {
  final CartoesRepository _repository;
  StreamSubscription? _parcelasSubscription;

  CartoesCubit({CartoesRepository? repository})
      : _repository = repository ?? CartoesRepository(),
        super(const CartoesState());

  void _escutarMudancasRealtime(String cartaoId) {
    _parcelasSubscription?.cancel();
    _parcelasSubscription = _repository.streamParcelas(cartaoId).listen((_) {
      carregarFatura(cartaoId, state.mesReferencia);
    });
  }

  Future<void> carregarCartoes({String? escopo}) async {
    emit(state.copyWith(status: CartoesStatus.loading));
    try {
      final escopoFiltro = escopo ?? state.filtroEscopo;
      final cartoes = await _repository.listarCartoes(escopo: escopoFiltro);

      Map<String, dynamic>? selecionado = state.cartaoSelecionado;
      if (cartoes.isNotEmpty) {
        if (selecionado == null || !cartoes.any((c) => c['id'] == selecionado!['id'])) {
          selecionado = cartoes.first;
        }
      } else {
        selecionado = null;
      }

      emit(state.copyWith(
        status: CartoesStatus.loaded,
        cartoes: cartoes,
        filtroEscopo: escopoFiltro,
        cartaoSelecionado: selecionado,
      ));

      if (selecionado != null) {
        _escutarMudancasRealtime(selecionado['id']);
        await carregarFatura(selecionado['id'], state.mesReferencia);
      }
    } catch (e) {
      emit(state.copyWith(
        status: CartoesStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  void selecionarCartao(Map<String, dynamic> cartao) {
    emit(state.copyWith(cartaoSelecionado: cartao));
    _escutarMudancasRealtime(cartao['id']);
    carregarFatura(cartao['id'], state.mesReferencia);
  }

  void mudarMesReferencia(String novoMes) {
    emit(state.copyWith(mesReferencia: novoMes));
    if (state.cartaoSelecionado != null) {
      carregarFatura(state.cartaoSelecionado!['id'], novoMes);
    }
  }

  Future<void> carregarFatura(String cartaoId, String mes) async {
    try {
      final fatura = await _repository.consultarFatura(cartaoId, mes);
      emit(state.copyWith(faturaDetalhada: fatura));
    } catch (_) {
      emit(state.copyWith(clearFatura: true));
    }
  }

  Future<bool> cadastrarCartao(Map<String, dynamic> dados) async {
    emit(state.copyWith(status: CartoesStatus.submitting));
    try {
      await _repository.cadastrarCartao(dados);
      emit(state.copyWith(
        status: CartoesStatus.success,
        successMessage: 'Cartão cadastrado com sucesso!',
      ));
      await carregarCartoes();
      return true;
    } catch (e) {
      emit(state.copyWith(
        status: CartoesStatus.error,
        errorMessage: e.toString(),
      ));
      return false;
    }
  }

  Future<bool> registrarDespesaCartao(Map<String, dynamic> dados) async {
    emit(state.copyWith(status: CartoesStatus.submitting));
    try {
      await _repository.registrarDespesaCartao(dados);

      // Re-busca imediatamente os cartões e seus limites atualizados
      final cartoesAtualizados = await _repository.listarCartoes(escopo: state.filtroEscopo);
      
      // Mantém ou ajusta o cartão selecionado
      final cartaoAfetadoId = dados['cartao_id']?.toString() ?? state.cartaoSelecionado?['id'];
      Map<String, dynamic>? novoSelecionado;
      if (cartoesAtualizados.isNotEmpty) {
        novoSelecionado = cartoesAtualizados.firstWhere(
          (c) => c['id'] == cartaoAfetadoId,
          orElse: () => state.cartaoSelecionado ?? cartoesAtualizados.first,
        );
      }

      // Re-busca a fatura do cartão selecionado
      Map<String, dynamic>? faturaAtualizada;
      if (novoSelecionado != null) {
        try {
          faturaAtualizada = await _repository.consultarFatura(novoSelecionado['id'], state.mesReferencia);
        } catch (_) {}
      }

      emit(state.copyWith(
        status: CartoesStatus.success,
        successMessage: 'Compra parcelada lançada com sucesso!',
        cartoes: cartoesAtualizados,
        cartaoSelecionado: novoSelecionado,
        faturaDetalhada: faturaAtualizada,
      ));
      return true;
    } catch (e) {
      emit(state.copyWith(
        status: CartoesStatus.error,
        errorMessage: e.toString(),
      ));
      return false;
    }
  }

  @override
  Future<void> close() {
    _parcelasSubscription?.cancel();
    return super.close();
  }
}
