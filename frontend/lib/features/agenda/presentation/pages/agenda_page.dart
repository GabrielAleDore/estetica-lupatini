import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../shell/main_navigation_shell.dart';
import '../../../vendas/domain/models/cliente_resumo.dart';
import '../../../vendas/domain/models/produto_servico_item.dart';
import '../../../vendas/presentation/cubit/vendas_cubit.dart';
import '../../domain/models/agendamento.dart';
import '../cubit/agenda_cubit.dart';
import '../cubit/agenda_state.dart';
import '../widgets/novo_agendamento_dialog.dart';
import '../widgets/relatorios_agendamento_tab.dart';
import '../widgets/whatsapp_template_dialog.dart';
import '../../../pacotes/presentation/widgets/gerenciar_pacotes_cliente_dialog.dart';

class AgendaPage extends StatefulWidget {
  final AgendaCubit? cubit;
  const AgendaPage({super.key, this.cubit});

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  @override
  void initState() {
    super.initState();
    initializeDateFormatting('pt_BR', null);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cubit != null) {
      return BlocProvider.value(
        value: widget.cubit!,
        child: const _AgendaView(),
      );
    }
    return BlocProvider(
      create: (_) => AgendaCubit()..inicializar(),
      child: const _AgendaView(),
    );
  }
}

class _AgendaView extends StatelessWidget {
  const _AgendaView();

  void _abrirModalNovoAgendamento(BuildContext context, AgendaState state) {
    final cubit = context.read<AgendaCubit>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => NovoAgendamentoDialog(
        clientes: state.clientes,
        servicos: state.servicos,
        dataInicial: state.dataSelecionada,
        onSalvar: ({
          required clienteId,
          required servicoId,
          required dataHoraInicio,
          required dataHoraFim,
          observacoes,
        }) =>
            cubit.criarAgendamento(
          clienteId: clienteId,
          servicoId: servicoId,
          dataHoraInicio: dataHoraInicio,
          dataHoraFim: dataHoraFim,
          observacoes: observacoes,
        ),
      ),
    );
  }

  void _abrirPacotesDoAgendamento(BuildContext context, Agendamento agendamento, AgendaState state) {
    showDialog(
      context: context,
      builder: (_) => GerenciarPacotesClienteDialog(
        clienteId: agendamento.clienteId,
        clienteNome: agendamento.clienteNome,
        servicos: state.servicos,
        agendamentoId: agendamento.id,
      ),
    );
  }

  void _abrirModalWhatsappTemplate(BuildContext context, AgendaState state) {
    final cubit = context.read<AgendaCubit>();
    showDialog(
      context: context,
      builder: (_) => WhatsappTemplateDialog(
        templateAtual: state.whatsappTemplate,
        onSalvar: (novoTemplate) => cubit.salvarWhatsappTemplate(novoTemplate),
      ),
    );
  }

  void _iniciarCheckoutNoPdv(BuildContext context, Agendamento agendamento) {
    try {
      final vendasCubit = context.read<VendasCubit>();

      // Localiza os dados do cliente e serviço para carregar com flags VIP e código
      final cliente = ClienteResumo(
        id: agendamento.clienteId,
        nome: agendamento.clienteNome,
        telefone: agendamento.clienteTelefone,
      );

      final servico = vendasCubit.state.catalogo.firstWhere(
        (item) => item.id == agendamento.servicoId,
        orElse: () => ProdutoServicoItem(
          id: agendamento.servicoId,
          nome: agendamento.servicoNome,
          tipo: TipoCatalogo.servico,
          preco: agendamento.servicoPreco,
          duracaoMinutos: agendamento.servicoDuracaoMinutos,
        ),
      );

      // Injeta cliente e serviço no carrinho do PDV
      vendasCubit.selecionarCliente(cliente);
      vendasCubit.adicionarItemAoCarrinho(servico);

      // Redireciona a navegação para o PDV
      MainNavigationShell.navegarPara('Frente de Caixa (PDV)');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF2E7D32),
          content: Text(
            'Atendimento de ${agendamento.clienteNome} aberto com sucesso no PDV!',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Não foi possível transferir para o PDV: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy (EEEE)', 'pt_BR');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda de Atendimentos & WhatsApp'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimaryLight,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recarregar Agenda',
            onPressed: () => context.read<AgendaCubit>().carregarAgendamentos(),
          ),
        ],
      ),
      body: BlocConsumer<AgendaCubit, AgendaState>(
        listener: (context, state) {
          if (state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(backgroundColor: const Color(0xFF2E7D32), content: Text(state.successMessage!)),
            );
          } else if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(backgroundColor: AppColors.error, content: Text(state.errorMessage!)),
            );
          }
        },
        builder: (context, state) {
          final cubit = context.read<AgendaCubit>();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra Superior: Navegação de Datas, Modos de Visão e Ações
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Controles de Data
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          tooltip: 'Anterior',
                          onPressed: () {
                            final delta = state.modoVisao == 'SEMANA' ? 7 : 1;
                            cubit.mudarData(state.dataSelecionada.subtract(Duration(days: delta)));
                          },
                        ),
                        InkWell(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: state.dataSelecionada,
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (d != null) cubit.mudarData(d);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_month, color: AppColors.primary, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  dateFormat.format(state.dataSelecionada),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          tooltip: 'Próximo',
                          onPressed: () {
                            final delta = state.modoVisao == 'SEMANA' ? 7 : 1;
                            cubit.mudarData(state.dataSelecionada.add(Duration(days: delta)));
                          },
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton(
                          onPressed: () => cubit.mudarData(DateTime.now()),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          child: const Text('HOJE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),

                    // Modos de Visão: Dia / Semana / Relatórios
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'DIA', label: Text('Dia'), icon: Icon(Icons.view_day, size: 16)),
                        ButtonSegment(value: 'SEMANA', label: Text('Semana'), icon: Icon(Icons.view_week, size: 16)),
                        ButtonSegment(value: 'RELATORIOS', label: Text('Métricas'), icon: Icon(Icons.analytics_outlined, size: 16)),
                      ],
                      selected: {state.modoVisao},
                      onSelectionChanged: (val) {
                        if (val.isNotEmpty) cubit.mudarModoVisao(val.first);
                      },
                    ),

                    // Botões de Ação: WhatsApp Template + Novo Agendamento
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _abrirModalWhatsappTemplate(context, state),
                          icon: const Icon(Icons.chat_outlined, size: 18, color: Color(0xFF2E7D32)),
                          label: const Text('CONFIGURAR WHATSAPP', style: TextStyle(fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2E7D32),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _abrirModalNovoAgendamento(context, state),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('NOVO AGENDAMENTO', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Seletor de Filtros de Status (exibido nas visões Dia e Semana)
              if (state.modoVisao != 'RELATORIOS')
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const Text('Filtrar: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(width: 8),
                        ...['TODOS', 'AGENDADO', 'CONFIRMADO', 'CONCLUIDO', 'CANCELADO'].map((status) {
                          final isSelected = state.filtroStatus == status;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: FilterChip(
                              label: Text(status),
                              selected: isSelected,
                              onSelected: (_) => cubit.mudarFiltroStatus(status),
                              selectedColor: AppColors.primarySubtle,
                              checkmarkColor: AppColors.primary,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? AppColors.primaryDark : AppColors.textPrimaryLight,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

              // Conteúdo Principal da Agenda
              Expanded(
                child: state.status == AgendaStatus.loading && state.agendamentos.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : state.modoVisao == 'RELATORIOS'
                        ? RelatoriosAgendamentoTab(
                            metricas: state.metricas,
                            onAtualizar: () => cubit.carregarAgendamentos(),
                          )
                        : state.modoVisao == 'SEMANA'
                            ? _buildVisaoSemanal(context, state, cubit)
                            : _buildVisaoDiaria(context, state, cubit),
              ),
            ],
          );
        },
      ),
    );
  }

  // Visão Diária com Cards e Linha do Tempo
  Widget _buildVisaoDiaria(BuildContext context, AgendaState state, AgendaCubit cubit) {
    if (state.agendamentos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_available, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Nenhum agendamento para este dia.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _abrirModalNovoAgendamento(context, state),
              icon: const Icon(Icons.add),
              label: const Text('Agendar Procedimento'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: state.agendamentos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final agendamento = state.agendamentos[index];
        return _buildAgendamentoCard(context, agendamento, cubit);
      },
    );
  }

  // Visão Semanal: Colunas para cada dia da semana
  Widget _buildVisaoSemanal(BuildContext context, AgendaState state, AgendaCubit cubit) {
    final d = state.dataSelecionada;
    final diaSemana = d.weekday;
    final segunda = DateTime(d.year, d.month, d.day - (diaSemana - 1));

    final dias = List.generate(7, (i) => segunda.add(Duration(days: i)));
    final diaFormat = DateFormat('EEE, dd/MM', 'pt_BR');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: dias.map((dia) {
        final isHoje = dia.day == DateTime.now().day && dia.month == DateTime.now().month && dia.year == DateTime.now().year;
        final agendamentosDia = state.agendamentos.where((a) {
          return a.dataHoraInicio.day == dia.day &&
              a.dataHoraInicio.month == dia.month &&
              a.dataHoraInicio.year == dia.year;
        }).toList();

        return Expanded(
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isHoje ? const Color(0xFFF1F8E9) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isHoje ? AppColors.primary : AppColors.borderLight,
                width: isHoje ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                  decoration: BoxDecoration(
                    color: isHoje ? AppColors.primarySubtle : Colors.grey.shade100,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        diaFormat.format(dia),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isHoje ? FontWeight.bold : FontWeight.w600,
                          color: isHoje ? AppColors.primaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: agendamentosDia.isNotEmpty ? AppColors.primary : Colors.grey.shade400,
                        child: Text(
                          agendamentosDia.length.toString(),
                          style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: agendamentosDia.isEmpty
                      ? const Center(child: Text('Sem horários', style: TextStyle(fontSize: 11, color: Colors.grey)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(6),
                          itemCount: agendamentosDia.length,
                          itemBuilder: (context, i) {
                            final a = agendamentosDia[i];
                            return _buildCardCompactoSemana(context, a, cubit);
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // Card Detalhado para a Visão Diária
  Widget _buildAgendamentoCard(BuildContext context, Agendamento agendamento, AgendaCubit cubit) {
    final horaFormat = DateFormat('HH:mm');
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    final corStatus = _obterCorStatus(agendamento.status);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: corStatus.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bloco de Horário e Duração
            Container(
              width: 100,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.primarySubtle,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    horaFormat.format(agendamento.dataHoraInicio),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                  ),
                  Text(
                    'às ${horaFormat.format(agendamento.dataHoraFim)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${agendamento.servicoDuracaoMinutos} min',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Informações da Cliente e Serviço
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        agendamento.clienteNome,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      // Badge de Status
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: corStatus.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: corStatus.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          agendamento.status,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: corStatus),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Telefone e WhatsApp Info
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        agendamento.clienteTelefone.isNotEmpty ? agendamento.clienteTelefone : 'Sem telefone',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      if (agendamento.lembreteEnviado) ...[
                        const SizedBox(width: 10),
                        const Icon(Icons.check_circle, size: 14, color: Color(0xFF2E7D32)),
                        const SizedBox(width: 3),
                        const Text(
                          'Lembrete WhatsApp Enviado',
                          style: TextStyle(fontSize: 11, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Serviço e Preço
                  Row(
                    children: [
                      const Icon(Icons.spa, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        agendamento.servicoNome,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        currencyFormat.format(agendamento.servicoPreco),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                      ),
                    ],
                  ),

                  // Observações
                  if (agendamento.observacoes != null && agendamento.observacoes!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 14, color: Colors.amber),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              agendamento.observacoes!,
                              style: const TextStyle(fontSize: 12, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Botões de Ação do Card
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Linha de Ações: WhatsApp + Alterar Status + Excluir
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Botão WhatsApp Rápido
                    ElevatedButton.icon(
                      onPressed: () => cubit.enviarWhatsapp(agendamento),
                      icon: const Icon(Icons.chat, size: 16),
                      label: Text(agendamento.lembreteEnviado ? 'Reenviar WhatsApp' : 'Enviar WhatsApp'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Menu de Status
                    PopupMenuButton<String>(
                      tooltip: 'Alterar Status',
                      icon: const Icon(Icons.edit_note, color: AppColors.primary),
                      onSelected: (novoStatus) => cubit.atualizarStatus(agendamento.id, novoStatus),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'AGENDADO', child: Text('Marcar como AGENDADO')),
                        PopupMenuItem(value: 'CONFIRMADO', child: Text('Marcar como CONFIRMADO')),
                        PopupMenuItem(value: 'CONCLUIDO', child: Text('Marcar como CONCLUÍDO (Atendido)')),
                        PopupMenuItem(value: 'CANCELADO', child: Text('Marcar como CANCELADO')),
                      ],
                    ),

                    // Excluir
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                      tooltip: 'Excluir Agendamento',
                      onPressed: () => _confirmarExclusao(context, agendamento, cubit),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Ações Rápidas: Consumir Sessão de Pacote ou Faturar no PDV
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _abrirPacotesDoAgendamento(context, agendamento, cubit.state),
                      icon: const Icon(Icons.collections_bookmark_outlined, size: 14),
                      label: const Text('PACOTES / SESSÃO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryDark,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    if (agendamento.status == 'CONCLUIDO' || agendamento.status == 'CONFIRMADO')
                      ElevatedButton.icon(
                        onPressed: () => _iniciarCheckoutNoPdv(context, agendamento),
                        icon: const Icon(Icons.point_of_sale, size: 14),
                        label: const Text('COBRAR NO PDV', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: agendamento.status == 'CONCLUIDO' ? const Color(0xFF1B5E20) : AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Card Compacto para Visão Semanal
  Widget _buildCardCompactoSemana(BuildContext context, Agendamento agendamento, AgendaCubit cubit) {
    final horaFormat = DateFormat('HH:mm');
    final corStatus = _obterCorStatus(agendamento.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: corStatus.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${horaFormat.format(agendamento.dataHoraInicio)} - ${horaFormat.format(agendamento.dataHoraFim)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primaryDark),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: corStatus, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            agendamento.clienteNome,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            agendamento.servicoNome,
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondaryLight),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: () => cubit.enviarWhatsapp(agendamento),
                child: const Icon(Icons.chat, size: 14, color: Color(0xFF2E7D32)),
              ),
              const SizedBox(width: 8),
              if (agendamento.status == 'CONCLUIDO')
                InkWell(
                  onTap: () => _iniciarCheckoutNoPdv(context, agendamento),
                  child: const Icon(Icons.point_of_sale, size: 14, color: Color(0xFF1B5E20)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _obterCorStatus(String status) {
    switch (status) {
      case 'AGENDADO':
        return const Color(0xFF1976D2); // Azul
      case 'CONFIRMADO':
        return const Color(0xFF388E3C); // Verde
      case 'CONCLUIDO':
        return const Color(0xFF00796B); // Verde Esmeralda / Teal
      case 'CANCELADO':
        return const Color(0xFFD32F2F); // Vermelho
      default:
        return Colors.grey;
    }
  }

  void _confirmarExclusao(BuildContext context, Agendamento agendamento, AgendaCubit cubit) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir Agendamento?'),
        content: Text('Tem certeza que deseja cancelar e excluir o agendamento de ${agendamento.clienteNome}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Voltar')),
          ElevatedButton(
            onPressed: () {
              cubit.excluirAgendamento(agendamento.id);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}
