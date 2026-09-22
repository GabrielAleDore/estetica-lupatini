import 'package:equatable/equatable.dart';

class Agendamento extends Equatable {
  final String id;
  final String clienteId;
  final String clienteNome;
  final String clienteTelefone;
  final String servicoId;
  final String servicoNome;
  final double servicoPreco;
  final int servicoDuracaoMinutos;
  final DateTime dataHoraInicio;
  final DateTime dataHoraFim;
  final String status; // 'AGENDADO', 'CONFIRMADO', 'CANCELADO', 'CONCLUIDO'
  final String? observacoes;
  final bool lembreteEnviado;
  final DateTime? createdAt;

  const Agendamento({
    required this.id,
    required this.clienteId,
    required this.clienteNome,
    required this.clienteTelefone,
    required this.servicoId,
    required this.servicoNome,
    required this.servicoPreco,
    required this.servicoDuracaoMinutos,
    required this.dataHoraInicio,
    required this.dataHoraFim,
    this.status = 'AGENDADO',
    this.observacoes,
    this.lembreteEnviado = false,
    this.createdAt,
  });

  bool get isAgendado => status == 'AGENDADO';
  bool get isConfirmado => status == 'CONFIRMADO';
  bool get isCancelado => status == 'CANCELADO';
  bool get isConcluido => status == 'CONCLUIDO';

  Duration get duracao => dataHoraFim.difference(dataHoraInicio);

  factory Agendamento.fromJson(Map<String, dynamic> json) {
    final cliente = json['clientes'] as Map<String, dynamic>?;
    final servico = json['servicos'] as Map<String, dynamic>?;

    final dataInicio = DateTime.parse(json['data_hora_inicio'].toString()).toLocal();
    final dataFim = json['data_hora_fim'] != null
        ? DateTime.parse(json['data_hora_fim'].toString()).toLocal()
        : dataInicio.add(Duration(minutes: (servico?['duracao_minutos'] ?? 60) as int));

    return Agendamento(
      id: json['id'] as String,
      clienteId: json['cliente_id'] as String,
      clienteNome: (cliente?['nome'] ?? cliente?['nome_completo'] ?? json['cliente_nome'] ?? 'Cliente sem nome') as String,
      clienteTelefone: (cliente?['telefone'] ?? json['cliente_telefone'] ?? '') as String,
      servicoId: json['servico_id'] as String,
      servicoNome: (servico?['nome'] ?? json['servico_nome'] ?? 'Serviço') as String,
      servicoPreco: (servico?['preco'] != null
          ? (servico!['preco'] as num).toDouble()
          : (json['servico_preco'] as num?)?.toDouble() ?? 0.0),
      servicoDuracaoMinutos: (servico?['duracao_minutos'] != null
          ? (servico!['duracao_minutos'] as num).toInt()
          : (json['servico_duracao'] as num?)?.toInt() ?? 60),
      dataHoraInicio: dataInicio,
      dataHoraFim: dataFim,
      status: (json['status'] ?? 'AGENDADO') as String,
      observacoes: json['observacoes'] as String?,
      lembreteEnviado: (json['lembrete_enviado'] ?? false) as bool,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'].toString()).toLocal() : null,
    );
  }

  Map<String, dynamic> toSupabaseInsert() {
    return {
      'cliente_id': clienteId,
      'servico_id': servicoId,
      'data_hora_inicio': dataHoraInicio.toUtc().toIso8601String(),
      'data_hora_fim': dataHoraFim.toUtc().toIso8601String(),
      'status': status,
      'observacoes': observacoes,
      'lembrete_enviado': lembreteEnviado,
    };
  }

  Agendamento copyWith({
    String? id,
    String? clienteId,
    String? clienteNome,
    String? clienteTelefone,
    String? servicoId,
    String? servicoNome,
    double? servicoPreco,
    int? servicoDuracaoMinutos,
    DateTime? dataHoraInicio,
    DateTime? dataHoraFim,
    String? status,
    String? observacoes,
    bool? lembreteEnviado,
    DateTime? createdAt,
  }) {
    return Agendamento(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      clienteNome: clienteNome ?? this.clienteNome,
      clienteTelefone: clienteTelefone ?? this.clienteTelefone,
      servicoId: servicoId ?? this.servicoId,
      servicoNome: servicoNome ?? this.servicoNome,
      servicoPreco: servicoPreco ?? this.servicoPreco,
      servicoDuracaoMinutos: servicoDuracaoMinutos ?? this.servicoDuracaoMinutos,
      dataHoraInicio: dataHoraInicio ?? this.dataHoraInicio,
      dataHoraFim: dataHoraFim ?? this.dataHoraFim,
      status: status ?? this.status,
      observacoes: observacoes ?? this.observacoes,
      lembreteEnviado: lembreteEnviado ?? this.lembreteEnviado,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        clienteId,
        clienteNome,
        clienteTelefone,
        servicoId,
        servicoNome,
        servicoPreco,
        servicoDuracaoMinutos,
        dataHoraInicio,
        dataHoraFim,
        status,
        observacoes,
        lembreteEnviado,
        createdAt,
      ];
}
