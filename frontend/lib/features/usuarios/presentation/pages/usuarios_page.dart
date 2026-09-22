import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';

class UsuariosPage extends StatelessWidget {
  final AuthCubit? cubit;
  const UsuariosPage({super.key, this.cubit});

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(value: cubit!, child: const _UsuariosView());
    }
    return const _UsuariosView();
  }
}

class _UsuariosView extends StatefulWidget {
  const _UsuariosView();

  @override
  State<_UsuariosView> createState() => _UsuariosViewState();
}

class _UsuariosViewState extends State<_UsuariosView> {
  @override
  void initState() {
    super.initState();
    context.read<AuthCubit>().carregarColaboradores();
  }

  void _abrirModalNovoUsuario(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<AuthCubit>(),
        child: const _NovoUsuarioDialog(),
      ),
    );
  }

  Color _corPerfil(String role) {
    switch (role.toUpperCase()) {
      case 'MESTRE':
        return const Color(0xFF6B21A8);
      case 'ADMIN':
        return AppColors.primary;
      case 'RECEPCAO':
        return Colors.indigo;
      case 'ATENDIMENTO':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          final colaboradores = state.listaColaboradores;

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabeçalho da Tela
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Gestão de Usuários & Colaboradores',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Controle de Acesso Baseado em Perfis (RBAC) - Admin, Recepção e Atendimento',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _abrirModalNovoUsuario(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                      icon: const Icon(Icons.person_add, size: 18),
                      label: const Text('Novo Colaborador', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Tabela de Usuários
                Expanded(
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.borderLight),
                    ),
                    color: Colors.white,
                    child: colaboradores.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: colaboradores.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final user = colaboradores[index];
                              final currentUser = state.usuario;
                              final isMestre = currentUser?.isMestre ?? false;
                              final podeAlternar = !user.isMestre && 
                                  (isMestre || (!user.isAdmin && (currentUser?.isAdmin ?? false)));
                              final roleColor = _corPerfil(user.role);

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: roleColor.withValues(alpha: 0.15),
                                  child: Icon(
                                    user.isMestre
                                        ? Icons.verified_user
                                        : user.isAdmin
                                            ? Icons.admin_panel_settings
                                            : user.isRecepcao
                                                ? Icons.desk
                                                : Icons.face_retouching_natural,
                                    color: roleColor,
                                    size: 20,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Text(
                                      user.nome,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: roleColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        user.role,
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: roleColor),
                                      ),
                                    ),
                                    if (user.isMestre) ...[
                                      const SizedBox(width: 6),
                                      const Tooltip(
                                        message: 'Usuário Mestre com controle de segurança máximo',
                                        child: Icon(Icons.shield, size: 14, color: Color(0xFF6B21A8)),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Text(
                                  user.email,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      user.ativo ? 'Ativo' : 'Inativo',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: user.ativo ? AppColors.success : AppColors.error,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Switch(
                                      value: user.ativo,
                                      activeThumbColor: AppColors.success,
                                      onChanged: podeAlternar
                                          ? (val) {
                                              context.read<AuthCubit>().alternarStatusUsuario(user.id, user.ativo);
                                            }
                                          : null,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NovoUsuarioDialog extends StatefulWidget {
  const _NovoUsuarioDialog();

  @override
  State<_NovoUsuarioDialog> createState() => _NovoUsuarioDialogState();
}

class _NovoUsuarioDialogState extends State<_NovoUsuarioDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  String _role = 'ATENDIMENTO';
  bool _isLoading = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      final sucesso = await context.read<AuthCubit>().cadastrarNovoUsuario(
        nome: _nomeController.text,
        email: _emailController.text,
        password: _senhaController.text,
        role: _role,
      );
      if (mounted) {
        setState(() => _isLoading = false);
        if (sucesso) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Colaborador cadastrado com sucesso!'), backgroundColor: AppColors.success),
          );
        } else {
          final erro = context.read<AuthCubit>().state.errorMessage ?? 'Erro ao cadastrar.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(erro), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.person_add_alt_1, color: AppColors.primary),
          SizedBox(width: 8),
          Text('Cadastrar Novo Colaborador', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(labelText: 'Nome Completo *', border: OutlineInputBorder()),
                validator: (val) => val == null || val.trim().isEmpty ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-mail de Acesso *', border: OutlineInputBorder()),
                validator: (val) => val == null || !val.contains('@') ? 'Informe um e-mail válido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _senhaController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Senha Inicial (mínimo 6 dígitos) *', border: OutlineInputBorder()),
                validator: (val) => val == null || val.length < 6 ? 'Mínimo de 6 caracteres' : null,
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final currentUser = context.read<AuthCubit>().state.usuario;
                  final isMestre = currentUser?.isMestre ?? false;

                  final items = <DropdownMenuItem<String>>[
                    if (isMestre)
                      const DropdownMenuItem(value: 'ADMIN', child: Text('Administrador Geral (Gestão Total)')),
                    const DropdownMenuItem(value: 'RECEPCAO', child: Text('Recepção (PDV, Clientes e Agendamentos)')),
                    const DropdownMenuItem(value: 'ATENDIMENTO', child: Text('Atendimento (Apenas PDV/Execução)')),
                  ];

                  return DropdownButtonFormField<String>(
                    initialValue: isMestre ? _role : (_role == 'ADMIN' ? 'RECEPCAO' : _role),
                    decoration: const InputDecoration(labelText: 'Perfil de Acesso (Role) *', border: OutlineInputBorder()),
                    items: items,
                    onChanged: (val) {
                      if (val != null) setState(() => _role = val);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _salvar,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          child: _isLoading
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Cadastrar'),
        ),
      ],
    );
  }
}
