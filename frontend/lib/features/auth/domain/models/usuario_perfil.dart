import 'package:equatable/equatable.dart';

class UsuarioPerfil extends Equatable {
  final String id;
  final String nome;
  final String email;
  final String role; // 'ADMIN', 'RECEPCAO', 'ATENDIMENTO'
  final bool ativo;

  const UsuarioPerfil({
    required this.id,
    required this.nome,
    required this.email,
    required this.role,
    this.ativo = true,
  });

  bool get isMestre => role == 'MESTRE';
  bool get isAdmin => role == 'ADMIN';
  bool get isRecepcao => role == 'RECEPCAO';
  bool get isAtendimento => role == 'ATENDIMENTO';
  bool get podeGerenciarUsuarios => isMestre || isAdmin;

  factory UsuarioPerfil.fromJson(Map<String, dynamic> json) {
    return UsuarioPerfil(
      id: json['id'] as String,
      nome: json['nome'] as String? ?? 'Usuário',
      email: json['email'] as String? ?? '',
      role: (json['role'] as String? ?? 'ATENDIMENTO').toUpperCase(),
      ativo: json['ativo'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'email': email,
      'role': role,
      'ativo': ativo,
    };
  }

  @override
  List<Object?> get props => [id, nome, email, role, ativo];
}
