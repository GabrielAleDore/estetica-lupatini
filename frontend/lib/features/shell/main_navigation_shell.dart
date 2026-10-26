import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/app_colors.dart';
import '../../core/responsive/responsive_layout.dart';
import '../auth/presentation/cubit/auth_cubit.dart';
import '../auth/presentation/cubit/auth_state.dart';
import '../auth/presentation/pages/login_page.dart';
import '../vendas/presentation/pages/pdv_page.dart';
import '../vendas/presentation/pages/movimentacoes_vendas_page.dart';
import '../dashboard/presentation/pages/dashboard_page.dart';
import '../cartoes/presentation/pages/cartoes_page.dart';
import '../clientes/presentation/pages/clientes_page.dart';
import '../catalogo/presentation/pages/catalogo_page.dart';
import '../contas_pagar/presentation/pages/contas_pagar_page.dart';
import '../usuarios/presentation/pages/usuarios_page.dart';
import '../agenda/presentation/pages/agenda_page.dart';
import '../contas_bancarias/presentation/pages/contas_bancarias_page.dart';
import '../operacoes/presentation/pages/cockpit_operacoes_page.dart';
import '../estoque/presentation/pages/movimentacao_estoque_page.dart';

class _NavDestinationItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
  final List<String> rolesPermitidas;

  const _NavDestinationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.page,
    required this.rolesPermitidas,
  });
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  /// Permite que qualquer tela envie uma solicitação para navegar até um destino específico
  static final ValueNotifier<String?> navigationTarget = ValueNotifier<String?>(null);

  static void navegarPara(String destinoLabel) {
    navigationTarget.value = destinoLabel;
  }

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    MainNavigationShell.navigationTarget.addListener(_aoMudarDestino);
  }

  @override
  void dispose() {
    MainNavigationShell.navigationTarget.removeListener(_aoMudarDestino);
    super.dispose();
  }

  void _aoMudarDestino() {
    final target = MainNavigationShell.navigationTarget.value;
    if (target != null && mounted) {
      final destinos = _obterDestinosFiltrados(context.read<AuthCubit>().state.usuario?.role ?? '');
      String query = target.toLowerCase();
      if (query.contains('vendas')) query = 'receitas';
      if (query.contains('pagar')) query = 'despesas';
      if (query.contains('estoque')) query = 'movimentação de estoque';
      if (query.contains('cockpit') || query.contains('operaç') || query.contains('inicio') || query.contains('início')) query = 'início';
      final idx = destinos.indexWhere((d) => d.label.toLowerCase().contains(query));
      if (idx != -1) {
        setState(() => _currentIndex = idx);
      }
      MainNavigationShell.navigationTarget.value = null;
    }
  }

  // Catálogo completo de destinos e suas restrições de RBAC
  static const List<_NavDestinationItem> _todosDestinos = [
    _NavDestinationItem(
      label: 'Início',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      page: CockpitOperacoesPage(),
      rolesPermitidas: ['ADMIN', 'RECEPCAO', 'ATENDIMENTO'],
    ),
    _NavDestinationItem(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      page: DashboardPage(),
      rolesPermitidas: ['ADMIN'],
    ),
    _NavDestinationItem(
      label: 'Agenda & WhatsApp',
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month,
      page: AgendaPage(),
      rolesPermitidas: ['ADMIN', 'RECEPCAO', 'ATENDIMENTO'],
    ),
    _NavDestinationItem(
      label: 'Frente de Caixa (PDV)',
      icon: Icons.point_of_sale_outlined,
      selectedIcon: Icons.point_of_sale,
      page: PdvPage(),
      rolesPermitidas: ['ADMIN', 'RECEPCAO', 'ATENDIMENTO'],
    ),
    _NavDestinationItem(
      label: 'Registro de Receitas',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      page: MovimentacoesVendasPage(),
      rolesPermitidas: ['ADMIN', 'RECEPCAO'],
    ),
    _NavDestinationItem(
      label: 'Registro de Despesas',
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet,
      page: ContasPagarPage(),
      rolesPermitidas: ['ADMIN'],
    ),
    _NavDestinationItem(
      label: 'Gestão de Cartões',
      icon: Icons.credit_card_outlined,
      selectedIcon: Icons.credit_card,
      page: CartoesPage(),
      rolesPermitidas: ['ADMIN'],
    ),
    _NavDestinationItem(
      label: 'Clientes & Anamnese',
      icon: Icons.assignment_ind_outlined,
      selectedIcon: Icons.assignment_ind,
      page: ClientesPage(),
      rolesPermitidas: ['ADMIN', 'RECEPCAO'],
    ),
    _NavDestinationItem(
      label: 'Catálogo & Insumos',
      icon: Icons.category_outlined,
      selectedIcon: Icons.category,
      page: CatalogoPage(),
      rolesPermitidas: ['ADMIN', 'RECEPCAO'],
    ),
    _NavDestinationItem(
      label: 'Movimentação de Estoque',
      icon: Icons.swap_horiz_outlined,
      selectedIcon: Icons.swap_horiz,
      page: MovimentacaoEstoquePage(),
      rolesPermitidas: ['ADMIN', 'RECEPCAO'],
    ),
    _NavDestinationItem(
      label: 'Contas Bancárias',
      icon: Icons.account_balance_outlined,
      selectedIcon: Icons.account_balance,
      page: ContasBancariasPage(),
      rolesPermitidas: ['ADMIN', 'MESTRE'],
    ),
    _NavDestinationItem(
      label: 'Gestão de Usuários',
      icon: Icons.manage_accounts_outlined,
      selectedIcon: Icons.manage_accounts,
      page: UsuariosPage(),
      rolesPermitidas: ['ADMIN', 'MESTRE'],
    ),
  ];

  List<_NavDestinationItem> _obterDestinosFiltrados(String role) {
    if (role.toUpperCase() == 'ADMIN' || role.toUpperCase() == 'MESTRE') {
      return _todosDestinos;
    }
    return _todosDestinos
        .where((item) => item.rolesPermitidas.contains(role.toUpperCase()))
        .toList();
  }

  Color _corDaRole(String role) {
    switch (role.toUpperCase()) {
      case 'MESTRE':
        return Colors.deepPurple;
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

  String _rotuloDaRole(String role) {
    switch (role.toUpperCase()) {
      case 'MESTRE':
        return 'Mestre / Super Admin';
      case 'ADMIN':
        return 'Administrador';
      case 'RECEPCAO':
        return 'Recepção';
      case 'ATENDIMENTO':
        return 'Atendimento';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        // Se não autenticado, exibe a tela de login
        if (authState.status == AuthStatus.unauthenticated || authState.usuario == null) {
          return const LoginPage();
        }

        // Se estiver carregando sessão inicial, exibe splash/loader
        if (authState.status == AuthStatus.loading && authState.usuario == null) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('Carregando ambiente Estética Lupatini...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          );
        }

        final usuario = authState.usuario!;
        final destinos = _obterDestinosFiltrados(usuario.role);

        // Garante que o índice atual é válido para os destinos permitidos
        final activeIndex = _currentIndex >= destinos.length ? 0 : _currentIndex;
        final pagesWidget = destinos.isNotEmpty
            ? IndexedStack(
                index: activeIndex,
                children: destinos.map((d) => d.page).toList(),
              )
            : const SizedBox.shrink();

        return ResponsiveLayout(
          desktop: Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  backgroundColor: Colors.white,
                  selectedIndex: activeIndex,
                  onDestinationSelected: (index) => setState(() => _currentIndex = index),
                  extended: true,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Marca Lupatini
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.spa, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'LUPATINI',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    letterSpacing: 1.2,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                Text(
                                  'Clínica & Estética',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Card do Colaborador Logado (RBAC)
                        Container(
                          width: 200,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: _corDaRole(usuario.role),
                                    child: Text(
                                      usuario.nome.isNotEmpty ? usuario.nome[0].toUpperCase() : 'U',
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          usuario.nome,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          usuario.email,
                                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondaryLight),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _corDaRole(usuario.role).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _rotuloDaRole(usuario.role),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: _corDaRole(usuario.role),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.logout, size: 16, color: Colors.grey),
                                    tooltip: 'Sair / Trocar Conta',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => context.read<AuthCubit>().logout(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  destinations: destinos.map((dest) {
                    return NavigationRailDestination(
                      icon: Icon(dest.icon),
                      selectedIcon: Icon(dest.selectedIcon, color: AppColors.primary),
                      label: Text(dest.label),
                    );
                  }).toList(),
                ),
                const VerticalDivider(thickness: 1, width: 1, color: AppColors.borderLight),
                Expanded(child: pagesWidget),
              ],
            ),
          ),
          mobile: Scaffold(
            appBar: AppBar(
              title: Text(
                destinos.isNotEmpty ? destinos[activeIndex].label : 'Estética Lupatini',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.white,
              foregroundColor: AppColors.textPrimaryLight,
              elevation: 1,
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Chip(
                    label: Text(_rotuloDaRole(usuario.role), style: const TextStyle(fontSize: 11)),
                    backgroundColor: _corDaRole(usuario.role).withValues(alpha: 0.15),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, size: 20),
                  tooltip: 'Sair',
                  onPressed: () => context.read<AuthCubit>().logout(),
                ),
              ],
            ),
            drawer: Drawer(
              backgroundColor: Colors.white,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  DrawerHeader(
                    decoration: const BoxDecoration(
                      color: AppColors.backgroundLight,
                      border: Border(bottom: BorderSide(color: AppColors.borderLight)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.spa, color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 10),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'LUPATINI',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    letterSpacing: 1.1,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                Text(
                                  'Clínica & Estética',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: _corDaRole(usuario.role),
                              child: Text(
                                usuario.nome.isNotEmpty ? usuario.nome[0].toUpperCase() : 'U',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    usuario.nome,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    _rotuloDaRole(usuario.role),
                                    style: TextStyle(fontSize: 11, color: _corDaRole(usuario.role), fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ...destinos.asMap().entries.map((entry) {
                    final index = entry.key;
                    final dest = entry.value;
                    final isSelected = index == activeIndex;
                    return ListTile(
                      leading: Icon(
                        isSelected ? dest.selectedIcon : dest.icon,
                        color: isSelected ? AppColors.primary : AppColors.textSecondaryLight,
                      ),
                      title: Text(
                        dest.label,
                        style: TextStyle(
                          color: isSelected ? AppColors.primary : AppColors.textPrimaryLight,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      selected: isSelected,
                      selectedTileColor: AppColors.primarySubtle,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onTap: () {
                        setState(() => _currentIndex = index);
                        Navigator.of(context).pop();
                      },
                    );
                  }),
                  const Divider(color: AppColors.borderLight),
                  ListTile(
                    leading: const Icon(Icons.logout, color: AppColors.error),
                    title: const Text('Sair da Conta', style: TextStyle(color: AppColors.error, fontSize: 14)),
                    onTap: () {
                      Navigator.of(context).pop();
                      context.read<AuthCubit>().logout();
                    },
                  ),
                ],
              ),
            ),
            body: pagesWidget,
            bottomNavigationBar: destinos.length <= 5 && destinos.length > 1
                ? NavigationBar(
                    backgroundColor: Colors.white,
                    selectedIndex: activeIndex,
                    onDestinationSelected: (index) => setState(() => _currentIndex = index),
                    destinations: destinos.map((dest) {
                      return NavigationDestination(
                        icon: Icon(dest.icon),
                        selectedIcon: Icon(dest.selectedIcon, color: AppColors.primary),
                        label: dest.label.split(' ').first,
                      );
                    }).toList(),
                  )
                : null,
          ),
        );
      },
    );
  }
}
