import 'package:equatable/equatable.dart';
import '../../domain/models/cliente_pacote_model.dart';

enum PacotesStatus { initial, loading, loaded, success, failure }

class PacotesState extends Equatable {
  final PacotesStatus status;
  final List<ClientePacoteModel> pacotes;
  final List<Map<String, dynamic>> profissionais;
  final String? clienteIdSelecionado;
  final String? errorMessage;
  final String? successMessage;

  const PacotesState({
    this.status = PacotesStatus.initial,
    this.pacotes = const [],
    this.profissionais = const [],
    this.clienteIdSelecionado,
    this.errorMessage,
    this.successMessage,
  });

  int get totalSessoesDisponiveis =>
      pacotes.where((p) => p.hasSaldo).fold(0, (acc, p) => acc + p.quantidadeRestante);

  List<ClientePacoteModel> get pacotesAtivos =>
      pacotes.where((p) => p.hasSaldo).toList();

  PacotesState copyWith({
    PacotesStatus? status,
    List<ClientePacoteModel>? pacotes,
    List<Map<String, dynamic>>? profissionais,
    String? clienteIdSelecionado,
    String? errorMessage,
    String? successMessage,
  }) {
    return PacotesState(
      status: status ?? this.status,
      pacotes: pacotes ?? this.pacotes,
      profissionais: profissionais ?? this.profissionais,
      clienteIdSelecionado: clienteIdSelecionado ?? this.clienteIdSelecionado,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        pacotes,
        profissionais,
        clienteIdSelecionado,
        errorMessage,
        successMessage,
      ];
}
