import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/operacoes_repository.dart';
import 'operacoes_state.dart';

class OperacoesCubit extends Cubit<OperacoesState> {
  final OperacoesRepository _repository;

  OperacoesCubit({OperacoesRepository? repository})
      : _repository = repository ?? OperacoesRepository(),
        super(OperacoesState(dataReferencia: DateTime.now()));

  Future<void> carregarCockpit({DateTime? data}) async {
    final dataAlvo = data ?? state.dataReferencia;
    emit(state.copyWith(status: OperacoesStatus.loading, dataReferencia: dataAlvo));

    try {
      final cockpitData = await _repository.carregarCockpitData(dataReferencia: dataAlvo);
      emit(state.copyWith(
        status: OperacoesStatus.loaded,
        data: cockpitData,
        errorMessage: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: OperacoesStatus.error,
        errorMessage: 'Erro ao carregar dados operacionais: $e',
      ));
    }
  }

  Future<void> mudarDataSelecionada(DateTime novaData) async {
    if (state.data == null) {
      await carregarCockpit(data: novaData);
      return;
    }

    // Se for do mesmo mês, podemos atualizar a data selecionada e carregar os agendamentos
    emit(state.copyWith(
      dataReferencia: novaData,
      status: OperacoesStatus.loading,
    ));

    try {
      final cockpitData = await _repository.carregarCockpitData(dataReferencia: novaData);
      emit(state.copyWith(
        status: OperacoesStatus.loaded,
        data: cockpitData,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: OperacoesStatus.error,
        errorMessage: 'Erro ao atualizar data selecionada: $e',
      ));
    }
  }
}
