import 'package:equatable/equatable.dart';
import '../../domain/models/agendamento.dart';

enum AgendaStatus { initial, loading, success, error }

class AgendaState extends Equatable {
  final AgendaStatus status;
  final List<Agendamento> agendamentos;
  final DateTime dataSelecionada;
  final String modoVisao; // 'DIA', 'SEMANA', 'RELATORIOS'
  final String filtroStatus; // 'TODOS', 'AGENDADO', 'CONFIRMADO', 'CONCLUIDO', 'CANCELADO'
  final List<Map<String, dynamic>> clientes;
  final List<Map<String, dynamic>> servicos;
  final Map<String, dynamic> metricas;
  final String whatsappTemplate;
  final String? errorMessage;
  final String? successMessage;

  const AgendaState({
    this.status = AgendaStatus.initial,
    this.agendamentos = const [],
    required this.dataSelecionada,
    this.modoVisao = 'DIA',
    this.filtroStatus = 'TODOS',
    this.clientes = const [],
    this.servicos = const [],
    this.metricas = const {},
    this.whatsappTemplate =
        'Olá {nome_cliente}! Seu agendamento na Clínica Lupatini para o procedimento "{servico}" está marcado para {data} às {horario}. Se precisar de ajustes ou para confirmar sua presença, por favor responda esta mensagem! ✨',
    this.errorMessage,
    this.successMessage,
  });

  AgendaState copyWith({
    AgendaStatus? status,
    List<Agendamento>? agendamentos,
    DateTime? dataSelecionada,
    String? modoVisao,
    String? filtroStatus,
    List<Map<String, dynamic>>? clientes,
    List<Map<String, dynamic>>? servicos,
    Map<String, dynamic>? metricas,
    String? whatsappTemplate,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return AgendaState(
      status: status ?? this.status,
      agendamentos: agendamentos ?? this.agendamentos,
      dataSelecionada: dataSelecionada ?? this.dataSelecionada,
      modoVisao: modoVisao ?? this.modoVisao,
      filtroStatus: filtroStatus ?? this.filtroStatus,
      clientes: clientes ?? this.clientes,
      servicos: servicos ?? this.servicos,
      metricas: metricas ?? this.metricas,
      whatsappTemplate: whatsappTemplate ?? this.whatsappTemplate,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearMessages ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        agendamentos,
        dataSelecionada,
        modoVisao,
        filtroStatus,
        clientes,
        servicos,
        metricas,
        whatsappTemplate,
        errorMessage,
        successMessage,
      ];
}
