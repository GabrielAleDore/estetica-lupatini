import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/pacotes_repository.dart';
import 'pacotes_state.dart';

class PacotesCubit extends Cubit<PacotesState> {
  final PacotesRepository _repository;

  PacotesCubit({PacotesRepository? repository})
      : _repository = repository ?? PacotesRepository(),
        super(const PacotesState());

  Future<void> carregarPacotes(String clienteId) async {
    emit(state.copyWith(status: PacotesStatus.loading, clienteIdSelecionado: clienteId));
    try {
      final pacotes = await _repository.carregarPacotesCliente(clienteId);
      final profissionais = state.profissionais.isEmpty
          ? await _repository.carregarProfissionais()
          : state.profissionais;

      emit(state.copyWith(
        status: PacotesStatus.loaded,
        pacotes: pacotes,
        profissionais: profissionais,
        errorMessage: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: PacotesStatus.failure,
        errorMessage: 'Erro ao carregar pacotes do cliente: $e',
      ));
    }
  }

  Future<bool> contratarPacote({
    required String clienteId,
    required String servicoId,
    required int quantidadeTotal,
    required double valorTotal,
    String? vendaOrigemId,
    String? tituloPersonalizado,
    int? validadeMeses,
    String? observacoes,
  }) async {
    emit(state.copyWith(status: PacotesStatus.loading));
    try {
      await _repository.contratarPacote(
        clienteId: clienteId,
        servicoId: servicoId,
        quantidadeTotal: quantidadeTotal,
        valorTotal: valorTotal,
        vendaOrigemId: vendaOrigemId,
        tituloPersonalizado: tituloPersonalizado,
        validadeMeses: validadeMeses,
        observacoes: observacoes,
      );

      emit(state.copyWith(
        status: PacotesStatus.success,
        successMessage: 'Pacote de $quantidadeTotal sessões contratado com sucesso!',
      ));
      await carregarPacotes(clienteId);
      return true;
    } catch (e) {
      emit(state.copyWith(
        status: PacotesStatus.failure,
        errorMessage: 'Falha ao contratar pacote: $e',
      ));
      return false;
    }
  }

  Future<bool> darBaixaSessao({
    required String pacoteId,
    String? profissionalId,
    String? agendamentoId,
    String? observacoesEvolucao,
    Map<String, dynamic>? parametrosUtilizados,
    List<String>? fotosUrls,
  }) async {
    emit(state.copyWith(status: PacotesStatus.loading));
    try {
      final res = await _repository.darBaixaSessao(
        pacoteId: pacoteId,
        profissionalId: profissionalId,
        agendamentoId: agendamentoId,
        observacoesEvolucao: observacoesEvolucao,
        parametrosUtilizados: parametrosUtilizados,
        fotosUrls: fotosUrls,
      );

      final msg = res['mensagem']?.toString() ?? 'Sessão registrada com sucesso!';

      emit(state.copyWith(
        status: PacotesStatus.success,
        successMessage: msg,
      ));

      if (state.clienteIdSelecionado != null) {
        await carregarPacotes(state.clienteIdSelecionado!);
      }
      return true;
    } catch (e) {
      emit(state.copyWith(
        status: PacotesStatus.failure,
        errorMessage: 'Falha ao registrar sessão: $e',
      ));
      return false;
    }
  }
}
