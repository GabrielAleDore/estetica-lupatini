import 'package:equatable/equatable.dart';

enum ClientesStatus { initial, loading, loaded, submitting, success, error }

class ClientesState extends Equatable {
  final ClientesStatus status;
  final List<Map<String, dynamic>> clientes;
  final String filtroBusca;
  final String? errorMessage;
  final String? successMessage;

  const ClientesState({
    this.status = ClientesStatus.initial,
    this.clientes = const [],
    this.filtroBusca = '',
    this.errorMessage,
    this.successMessage,
  });

  ClientesState copyWith({
    ClientesStatus? status,
    List<Map<String, dynamic>>? clientes,
    String? filtroBusca,
    String? errorMessage,
    String? successMessage,
  }) {
    return ClientesState(
      status: status ?? this.status,
      clientes: clientes ?? this.clientes,
      filtroBusca: filtroBusca ?? this.filtroBusca,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }

  @override
  List<Object?> get props => [status, clientes, filtroBusca, errorMessage, successMessage];
}
