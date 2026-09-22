import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/clientes_repository.dart';
import 'clientes_state.dart';

class ClientesCubit extends Cubit<ClientesState> {
  final ClientesRepository _repository;

  ClientesCubit({ClientesRepository? repository})
      : _repository = repository ?? ClientesRepository(),
        super(const ClientesState());

  Future<void> carregarClientes({String? busca}) async {
    emit(state.copyWith(status: ClientesStatus.loading));
    try {
      final lista = await _repository.listarClientes(busca: busca);
      emit(state.copyWith(
        status: ClientesStatus.loaded,
        clientes: lista,
        filtroBusca: busca ?? '',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ClientesStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<bool> cadastrarCliente(Map<String, dynamic> dados) async {
    emit(state.copyWith(status: ClientesStatus.submitting));
    try {
      await _repository.cadastrarCliente(dados);
      emit(state.copyWith(
        status: ClientesStatus.success,
        successMessage: 'Paciente cadastrado com sucesso!',
      ));
      await carregarClientes(busca: state.filtroBusca);
      return true;
    } catch (e) {
      emit(state.copyWith(
        status: ClientesStatus.error,
        errorMessage: e.toString(),
      ));
      return false;
    }
  }

  Future<void> atualizarFidelidade(String id, bool isFidelizada, double desconto) async {
    try {
      await _repository.atualizarFidelidade(id, isFidelizada, desconto);
      emit(state.copyWith(
        status: ClientesStatus.success,
        successMessage: isFidelizada 
            ? 'Cliente marcada como VIP Fidelidade ($desconto% desconto)!' 
            : 'Fidelidade desativada para a cliente.',
      ));
      await carregarClientes(busca: state.filtroBusca);
    } catch (e) {
      emit(state.copyWith(
        status: ClientesStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }
}
