import 'package:equatable/equatable.dart';

class ClienteResumo extends Equatable {
  final String id;
  final String nome;
  final String telefone;
  final String? cpf;
  final bool isFidelizada;
  final double descontoFidelidadePadrao;

  const ClienteResumo({
    required this.id,
    required this.nome,
    required this.telefone,
    this.cpf,
    this.isFidelizada = false,
    this.descontoFidelidadePadrao = 0.0,
  });

  factory ClienteResumo.fromJson(Map<String, dynamic> json) {
    return ClienteResumo(
      id: json['id'] as String,
      nome: json['nome'] as String,
      telefone: (json['telefone'] ?? '') as String,
      cpf: json['cpf'] as String?,
      isFidelizada: (json['is_fidelizada'] ?? false) as bool,
      descontoFidelidadePadrao: json['desconto_fidelidade_padrao'] != null
          ? (json['desconto_fidelidade_padrao'] as num).toDouble()
          : 0.0,
    );
  }

  @override
  List<Object?> get props => [id, nome, telefone, cpf, isFidelizada, descontoFidelidadePadrao];
}
