import 'package:equatable/equatable.dart';

class MovimentacaoEstoqueModel extends Equatable {
  final String id;
  final String produtoId;
  final String produtoNome;
  final String? produtoSku;
  final String unidadeMedida;
  final String tipo; // 'ENTRADA', 'SAIDA', 'CONSUMO'
  final double quantidade;
  final double saldoAnterior;
  final double saldoPosterior;
  final String? motivo;
  final String? vendaId;
  final DateTime createdAt;

  const MovimentacaoEstoqueModel({
    required this.id,
    required this.produtoId,
    required this.produtoNome,
    this.produtoSku,
    required this.unidadeMedida,
    required this.tipo,
    required this.quantidade,
    required this.saldoAnterior,
    required this.saldoPosterior,
    this.motivo,
    this.vendaId,
    required this.createdAt,
  });

  factory MovimentacaoEstoqueModel.fromJson(Map<String, dynamic> json) {
    final prodMap = json['produto'] is Map<String, dynamic>
        ? json['produto'] as Map<String, dynamic>
        : null;

    final parsedCreated = json['created_at'] != null
        ? DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now()
        : DateTime.now();

    return MovimentacaoEstoqueModel(
      id: json['id']?.toString() ?? '',
      produtoId: json['produto_id']?.toString() ?? '',
      produtoNome: prodMap?['nome']?.toString() ?? json['produto_nome']?.toString() ?? 'Produto não identificado',
      produtoSku: prodMap?['codigo_barras']?.toString() ?? json['codigo_barras']?.toString(),
      unidadeMedida: prodMap?['unidade_medida']?.toString() ?? json['unidade_medida']?.toString() ?? 'UN',
      tipo: (json['tipo']?.toString().toUpperCase() ?? 'ENTRADA'),
      quantidade: (json['quantidade'] as num?)?.toDouble() ?? 0.0,
      saldoAnterior: (json['saldo_anterior'] as num?)?.toDouble() ?? 0.0,
      saldoPosterior: (json['saldo_posterior'] as num?)?.toDouble() ?? 0.0,
      motivo: json['motivo']?.toString(),
      vendaId: json['venda_id']?.toString(),
      createdAt: parsedCreated,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'produto_id': produtoId,
      'tipo': tipo,
      'quantidade': quantidade,
      'saldo_anterior': saldoAnterior,
      'saldo_posterior': saldoPosterior,
      'motivo': motivo,
      'venda_id': vendaId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        produtoId,
        produtoNome,
        produtoSku,
        unidadeMedida,
        tipo,
        quantidade,
        saldoAnterior,
        saldoPosterior,
        motivo,
        vendaId,
        createdAt,
      ];
}
