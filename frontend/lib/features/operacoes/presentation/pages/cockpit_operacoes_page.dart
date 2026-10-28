import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../shell/main_navigation_shell.dart';
import '../../../clientes/data/clientes_repository.dart';
import '../../../clientes/presentation/widgets/novo_cliente_dialog.dart';
import '../../../contas_pagar/presentation/pages/contas_pagar_page.dart';
import '../../domain/models/cockpit_data.dart';
import '../cubit/operacoes_cubit.dart';
import '../cubit/operacoes_state.dart';
import '../widgets/acesso_rapido_cards.dart';
import '../widgets/saude_financeira_dia_grid.dart';
import '../widgets/resumo_periodo_table.dart';
import '../widgets/mini_calendario_operacional.dart';
import '../widgets/aniversariantes_semana_card.dart';

class CockpitOperacoesPage extends StatelessWidget {
  final OperacoesCubit? cubit;

  const CockpitOperacoesPage({super.key, this.cubit});

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(value: cubit!, child: const _CockpitView());
    }
    try {
      context.read<OperacoesCubit>();
      return const _CockpitView();
    } catch (_) {
      return BlocProvider(
        create: (_) => OperacoesCubit()..carregarCockpit(),
        child: const _CockpitView(),
      );
    }
  }
}

class _CockpitView extends StatefulWidget {
  const _CockpitView();

  @override
  State<_CockpitView> createState() => _CockpitViewState();
}

class _CockpitViewState extends State<_CockpitView> {
  @override
  void initState() {
    super.initState();
    final cubit = context.read<OperacoesCubit>();
    if (cubit.state.status == OperacoesStatus.initial) {
      cubit.carregarCockpit();
    }
  }

  void _abrirModalNovoAgendamento(BuildContext context) {
    MainNavigationShell.navegarPara('Agenda & WhatsApp');
  }

  void _abrirModalNovoCliente(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => NovoClienteDialog(
        onSalvar: (dados) async {
          try {
            await ClientesRepository().cadastrarCliente(dados);
            if (context.mounted) {
              context.read<OperacoesCubit>().carregarCockpit();
            }
            return true;
          } catch (_) {
            return false;
          }
        },
      ),
    );
  }

  void _abrirModalNovaDespesa(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ModalNovaDespesa(),
    ).then((_) {
      if (context.mounted) {
        context.read<OperacoesCubit>().carregarCockpit();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hojeFormatado = DateFormat("EEEE, d 'de' MMMM 'de' yyyy", 'pt_BR').format(DateTime.now());
    final hojeFormatadoCap = hojeFormatado[0].toUpperCase() + hojeFormatado.substring(1);
    final usuarioNome = context.watch<AuthCubit>().state.usuario?.nome ?? 'Colaborador';

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Início'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimaryLight,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar Dados',
            onPressed: () => context.read<OperacoesCubit>().carregarCockpit(),
          ),
        ],
      ),
      body: BlocConsumer<OperacoesCubit, OperacoesState>(
        listener: (context, state) {
          if (state.status == OperacoesStatus.error && state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!), backgroundColor: AppColors.error),
            );
          }
        },
        builder: (context, state) {
          if (state.status == OperacoesStatus.loading && state.data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = state.data;
          final cubit = context.read<OperacoesCubit>();

          return RefreshIndicator(
            onRefresh: () => cubit.carregarCockpit(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner de Boas-Vindas e Data Atual
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF344E41), Color(0xFF588157)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF344E41).withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.spa, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Olá, $usuarioNome! Central de Operações Estética Lupatini',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                hojeFormatadoCap,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Acesso Rápido (4 Botões de Ação)
                  AcessoRapidoCards(
                    onNovoAgendamento: () => _abrirModalNovoAgendamento(context),
                    onNovoCliente: () => _abrirModalNovoCliente(context),
                    onNovaVenda: () => MainNavigationShell.navegarPara('Frente de Caixa (PDV)'),
                    onNovaDespesa: () => _abrirModalNovaDespesa(context),
                  ),
                  const SizedBox(height: 20),

                  // Layout em Duas Colunas: Principal (Esquerda) vs Sidebar (Direita)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth > 1050;

                      final colunaEsquerda = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SaudeFinanceiraDiaGrid(
                            saude: data?.saudeFinanceira ?? const SaudeFinanceiraDia(),
                            onVerReceberHoje: () => MainNavigationShell.navegarPara('Registro de Receitas'),
                            onVerPagarHoje: () => MainNavigationShell.navegarPara('Contas a Pagar & Tesouraria'),
                            onVerRecebimentosVencidos: () => MainNavigationShell.navegarPara('Registro de Receitas'),
                            onVerPagamentosVencidos: () => MainNavigationShell.navegarPara('Contas a Pagar & Tesouraria'),
                          ),
                          const SizedBox(height: 20),
                          ResumoPeriodoTable(
                            resumo: data?.resumoPeriodo ?? const ResumoPeriodo(),
                            periodoLabel: DateFormat("MMMM 'de' yyyy", 'pt_BR').format(state.dataReferencia),
                          ),
                        ],
                      );

                      final colunaDireita = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MiniCalendarioOperacional(
                            dataSelecionada: state.dataReferencia,
                            diasComAgendamento: data?.diasComAgendamento ?? {},
                            agendamentosDoDia: data?.agendamentosDoDia ?? [],
                            onDiaSelecionado: (novaData) => cubit.mudarDataSelecionada(novaData),
                            onAbrirAgendaCompleta: () => MainNavigationShell.navegarPara('Agenda & WhatsApp'),
                          ),
                          const SizedBox(height: 20),
                          AniversariantesSemanaCard(
                            aniversariantes: data?.aniversariantesSemana ?? [],
                          ),
                        ],
                      );

                      if (isDesktop) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 65, child: colunaEsquerda),
                            const SizedBox(width: 20),
                            Expanded(flex: 35, child: colunaDireita),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          colunaEsquerda,
                          const SizedBox(height: 20),
                          colunaDireita,
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
