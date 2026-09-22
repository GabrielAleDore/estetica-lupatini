import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/vendas_historico_repository.dart';
import 'vendas_historico_state.dart';

class VendasHistoricoCubit extends Cubit<VendasHistoricoState> {
  final VendasHistoricoRepository _repository;
  StreamSubscription? _streamSubscription;

  VendasHistoricoCubit({VendasHistoricoRepository? repository})
      : _repository = repository ?? VendasHistoricoRepository(),
        super(const VendasHistoricoState()) {
    _iniciarRealtime();
  }

  void _iniciarRealtime() {
    _streamSubscription?.cancel();
    _streamSubscription = _repository.streamVendas().listen((_) {
      carregarVendas(silencioso: true);
    });
  }

  Future<void> carregarVendas({bool silencioso = false}) async {
    if (!silencioso) {
      emit(state.copyWith(status: HistoricoStatus.loading, clearMessages: true));
    }

    try {
      DateTime? inicio;
      DateTime? fim = DateTime.now().add(const Duration(days: 1));

      final agora = DateTime.now();
      if (state.filtroPeriodo == 'HOJE') {
        inicio = DateTime(agora.year, agora.month, agora.day);
      } else if (state.filtroPeriodo == '7DIAS') {
        inicio = agora.subtract(const Duration(days: 7));
      } else if (state.filtroPeriodo == 'MES') {
        inicio = DateTime(agora.year, agora.month, 1);
      } else {
        inicio = null;
        fim = null;
      }

      final vendas = await _repository.listarVendas(
        statusPagamento: state.filtroStatusPagamento,
        buscaCliente: state.buscaCliente,
        dataInicio: inicio,
        dataFim: fim,
      );

      emit(state.copyWith(
        status: HistoricoStatus.loaded,
        vendas: vendas,
        clearMessages: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: HistoricoStatus.error,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      ));
    }
  }

  void mudarFiltroStatus(String status) {
    emit(state.copyWith(filtroStatusPagamento: status));
    carregarVendas();
  }

  void mudarFiltroPeriodo(String periodo) {
    emit(state.copyWith(filtroPeriodo: periodo));
    carregarVendas();
  }

  void mudarBuscaCliente(String busca) {
    emit(state.copyWith(buscaCliente: busca));
    carregarVendas();
  }

  Future<bool> liquidarVendaPendente(String vendaId, String formaPagamento) async {
    try {
      await _repository.darBaixaVenda(vendaId, formaPagamento);
      emit(state.copyWith(successMessage: 'Venda liquidada com sucesso!'));
      await carregarVendas();
      return true;
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString().replaceAll('Exception: ', '')));
      return false;
    }
  }

  Future<bool> cancelarVenda(String vendaId) async {
    try {
      await _repository.cancelarVenda(vendaId);
      emit(state.copyWith(successMessage: 'Venda cancelada com sucesso!'));
      await carregarVendas();
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
