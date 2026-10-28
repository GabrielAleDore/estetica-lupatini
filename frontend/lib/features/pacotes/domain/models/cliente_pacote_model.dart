import 'package:equatable/equatable.dart';

class SessaoHistoricoModel extends Equatable {
  final String id;
  final int numeroSessao;
  final DateTime dataRealizacao;
  final String? profissionalId;
  final String? profissionalNome;
  final String? observacoesEvolucao;
  final Map<String, dynamic> parametrosUtilizados;
  final List<String> fotosSessaoUrls;

  const SessaoHistoricoModel({
    required this.id,
    required this.numeroSessao,
    required this.dataRealizacao,
    this.profissionalId,
    this.profissionalNome,
    this.observacoesEvolucao,
    this.parametrosUtilizados = const {},
    this.fotosSessaoUrls = const [],
  });

  factory SessaoHistoricoModel.fromJson(Map<String, dynamic> json) {
    return SessaoHistoricoModel(
      id: json['id'] as String? ?? '',
      numeroSessao: (json['numero_sessao'] as num?)?.toInt() ?? 1,
      dataRealizacao: json['data_realizacao'] != null
          ? DateTime.tryParse(json['data_realizacao'].toString()) ?? DateTime.now()
          : DateTime.now(),
      profissionalId: json['profissional_id'] as String?,
      profissionalNome: json['profissional_nome'] as String?,
      observacoesEvolucao: json['observacoes_evolucao'] as String?,
      parametrosUtilizados: json['parametros_utilizados'] is Map
          ? Map<String, dynamic>.from(json['parametros_utilizados'] as Map)
          : {},
      fotosSessaoUrls: json['fotos_sessao_urls'] is List
          ? (json['fotos_sessao_urls'] as List).map((e) => e.toString()).toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'numero_sessao': numeroSessao,
        'data_realizacao': dataRealizacao.toIso8601String(),
        'profissional_id': profissionalId,
        'profissional_nome': profissionalNome,
        'observacoes_evolucao': observacoesEvolucao,
        'parametros_utilizados': parametrosUtilizados,
        'fotos_sessao_urls': fotosSessaoUrls,
      };

  @override
  List<Object?> get props => [id, numeroSessao, dataRealizacao, profissionalId];
}

class ClientePacoteModel extends Equatable {
  final String id;
  final String clienteId;
  final String servicoId;
  final String servicoNome;
  final String? tituloPersonalizado;
  final int quantidadeTotal;
  final int quantidadeConsumida;
  final int quantidadeRestante;
  final double valorTotal;
  final double valorPorSessao;
  final DateTime dataAquisicao;
  final DateTime? dataValidade;
  final String status;
  final String? observacoes;
  final List<SessaoHistoricoModel> sessoes;

  const ClientePacoteModel({
    required this.id,
    required this.clienteId,
    required this.servicoId,
    required this.servicoNome,
    this.tituloPersonalizado,
    required this.quantidadeTotal,
    required this.quantidadeConsumida,
    required this.quantidadeRestante,
    required this.valorTotal,
    required this.valorPorSessao,
    required this.dataAquisicao,
    this.dataValidade,
    required this.status,
    this.observacoes,
    this.sessoes = const [],
  });

  String get tituloExibicao =>
      (tituloPersonalizado != null && tituloPersonalizado!.isNotEmpty)
          ? tituloPersonalizado!
          : '$quantidadeTotal sessões de $servicoNome';

  bool get hasSaldo => quantidadeRestante > 0 && status == 'ATIVO';

  factory ClientePacoteModel.fromJson(Map<String, dynamic> json) {
    final sessoesList = (json['sessoes'] as List?)
            ?.map((e) => SessaoHistoricoModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final total = (json['quantidade_total'] as num?)?.toInt() ?? 1;
    final consumida = (json['quantidade_consumida'] as num?)?.toInt() ?? 0;
    final restante = (json['quantidade_restante'] as num?)?.toInt() ?? (total - consumida);

    return ClientePacoteModel(
      id: json['id'] as String? ?? '',
      clienteId: json['cliente_id'] as String? ?? '',
      servicoId: json['servico_id'] as String? ?? '',
      servicoNome: json['servico_nome'] as String? ?? 'Serviço Clínico',
      tituloPersonalizado: json['titulo_personalizado'] as String?,
      quantidadeTotal: total,
      quantidadeConsumida: consumida,
      quantidadeRestante: restante,
      valorTotal: (json['valor_total'] as num?)?.toDouble() ?? 0.0,
      valorPorSessao: (json['valor_por_sessao'] as num?)?.toDouble() ?? 0.0,
      dataAquisicao: json['data_aquisicao'] != null
          ? DateTime.tryParse(json['data_aquisicao'].toString()) ?? DateTime.now()
          : DateTime.now(),
      dataValidade: json['data_validade'] != null
          ? DateTime.tryParse(json['data_validade'].toString())
          : null,
      status: json['status'] as String? ?? 'ATIVO',
      observacoes: json['observacoes'] as String?,
      sessoes: sessoesList,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'cliente_id': clienteId,
        'servico_id': servicoId,
        'servico_nome': servicoNome,
        'titulo_personalizado': tituloPersonalizado,
        'quantidade_total': quantidadeTotal,
        'quantidade_consumida': quantidadeConsumida,
        'quantidade_restante': quantidadeRestante,
        'valor_total': valorTotal,
        'valor_por_sessao': valorPorSessao,
        'data_aquisicao': dataAquisicao.toIso8601String(),
        'data_validade': dataValidade?.toIso8601String(),
        'status': status,
        'observacoes': observacoes,
        'sessoes': sessoes.map((e) => e.toJson()).toList(),
      };

  @override
  List<Object?> get props => [id, clienteId, servicoId, quantidadeConsumida, status];
}
