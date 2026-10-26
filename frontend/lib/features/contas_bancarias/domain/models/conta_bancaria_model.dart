import 'package:equatable/equatable.dart';

class ContaBancariaModel extends Equatable {
  final String id;
  final String nomeConta;
  final String bancoNome;
  final String? agencia;
  final String? numeroConta;
  final String tipoConta; // 'CORRENTE', 'POUPANCA', 'INVESTIMENTO'
  final String escopo; // 'PJ', 'PF'
  final String? chavePix;
  final double saldoInicial;
  final double saldoAtual;
  final String? corIdentificadora;
  final bool ativo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ContaBancariaModel({
    required this.id,
    required this.nomeConta,
    required this.bancoNome,
    this.agencia,
    this.numeroConta,
    this.tipoConta = 'CORRENTE',
    this.escopo = 'PJ',
    this.chavePix,
    this.saldoInicial = 0.0,
    this.saldoAtual = 0.0,
    this.corIdentificadora,
    this.ativo = true,
    this.createdAt,
    this.updatedAt,
  });

  bool get isPj => escopo.toUpperCase() == 'PJ';
  bool get isPf => escopo.toUpperCase() == 'PF';

  String get tipoContaFormatado {
    switch (tipoConta.toUpperCase()) {
      case 'POUPANCA':
        return 'Poupança';
      case 'INVESTIMENTO':
        return 'Aplicação / Investimento';
      case 'CORRENTE':
      default:
        return 'Conta Corrente';
    }
  }

  factory ContaBancariaModel.fromJson(Map<String, dynamic> json) {
    final saldoInicial = (json['saldo_inicial'] as num?)?.toDouble() ?? 0.0;
    final saldoAtual = json['saldo_atual'] != null
        ? (json['saldo_atual'] as num).toDouble()
        : saldoInicial;

    return ContaBancariaModel(
      id: json['id']?.toString() ?? '',
      nomeConta: json['nome_conta'] as String? ?? 'Conta Bancária',
      bancoNome: json['banco_nome'] as String? ?? 'Banco',
      agencia: json['agencia'] as String?,
      numeroConta: json['numero_conta'] as String?,
      tipoConta: json['tipo_conta'] as String? ?? 'CORRENTE',
      escopo: json['escopo'] as String? ?? 'PJ',
      chavePix: json['chave_pix'] as String?,
      saldoInicial: saldoInicial,
      saldoAtual: saldoAtual,
      corIdentificadora: json['cor_identificadora'] as String?,
      ativo: json['ativo'] as bool? ?? true,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString())?.toLocal() : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString())?.toLocal() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome_conta': nomeConta,
      'banco_nome': bancoNome,
      'agencia': agencia,
      'numero_conta': numeroConta,
      'tipo_conta': tipoConta,
      'escopo': escopo,
      'chave_pix': chavePix,
      'saldo_inicial': saldoInicial,
      'saldo_atual': saldoAtual,
      'cor_identificadora': corIdentificadora,
      'ativo': ativo,
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> toSupabaseInsert() {
    return {
      'nome_conta': nomeConta.trim(),
      'banco_nome': bancoNome.trim(),
      'agencia': agencia?.trim().isEmpty == true ? null : agencia?.trim(),
      'numero_conta': numeroConta?.trim().isEmpty == true ? null : numeroConta?.trim(),
      'tipo_conta': tipoConta,
      'escopo': escopo,
      'chave_pix': chavePix?.trim().isEmpty == true ? null : chavePix?.trim(),
      'saldo_inicial': saldoInicial,
      'saldo_atual': saldoAtual,
      'cor_identificadora': corIdentificadora ?? '#8D5B4C',
      'ativo': ativo,
    };
  }

  Map<String, dynamic> toSupabaseUpdate() {
    return {
      'nome_conta': nomeConta.trim(),
      'banco_nome': bancoNome.trim(),
      'agencia': agencia?.trim().isEmpty == true ? null : agencia?.trim(),
      'numero_conta': numeroConta?.trim().isEmpty == true ? null : numeroConta?.trim(),
      'tipo_conta': tipoConta,
      'escopo': escopo,
      'chave_pix': chavePix?.trim().isEmpty == true ? null : chavePix?.trim(),
      'saldo_inicial': saldoInicial,
      'saldo_atual': saldoAtual,
      'cor_identificadora': corIdentificadora ?? '#8D5B4C',
      'ativo': ativo,
    };
  }

  ContaBancariaModel copyWith({
    String? id,
    String? nomeConta,
    String? bancoNome,
    String? agencia,
    String? numeroConta,
    String? tipoConta,
    String? escopo,
    String? chavePix,
    double? saldoInicial,
    double? saldoAtual,
    String? corIdentificadora,
    bool? ativo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ContaBancariaModel(
      id: id ?? this.id,
      nomeConta: nomeConta ?? this.nomeConta,
      bancoNome: bancoNome ?? this.bancoNome,
      agencia: agencia ?? this.agencia,
      numeroConta: numeroConta ?? this.numeroConta,
      tipoConta: tipoConta ?? this.tipoConta,
      escopo: escopo ?? this.escopo,
      chavePix: chavePix ?? this.chavePix,
      saldoInicial: saldoInicial ?? this.saldoInicial,
      saldoAtual: saldoAtual ?? this.saldoAtual,
      corIdentificadora: corIdentificadora ?? this.corIdentificadora,
      ativo: ativo ?? this.ativo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        nomeConta,
        bancoNome,
        agencia,
        numeroConta,
        tipoConta,
        escopo,
        chavePix,
        saldoInicial,
        saldoAtual,
        corIdentificadora,
        ativo,
        createdAt,
        updatedAt,
      ];
}
