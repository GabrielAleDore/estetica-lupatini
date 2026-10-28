import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../cubit/pacotes_cubit.dart';
import '../cubit/pacotes_state.dart';
import 'novo_pacote_dialog.dart';
import 'dar_baixa_sessao_dialog.dart';
import 'historico_sessoes_dialog.dart';

class GerenciarPacotesClienteDialog extends StatelessWidget {
  final String clienteId;
  final String clienteNome;
  final List<Map<String, dynamic>> servicos;
  final String? agendamentoId;
  final PacotesCubit? cubit;

  const GerenciarPacotesClienteDialog({
    super.key,
    required this.clienteId,
    required this.clienteNome,
    required this.servicos,
    this.agendamentoId,
    this.cubit,
  });

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(
        value: cubit!,
        child: _GerenciarPacotesView(
          clienteId: clienteId,
          clienteNome: clienteNome,
          servicos: servicos,
          agendamentoId: agendamentoId,
        ),
      );
    }
    return BlocProvider(
      create: (_) => PacotesCubit()..carregarPacotes(clienteId),
      child: _GerenciarPacotesView(
        clienteId: clienteId,
        clienteNome: clienteNome,
        servicos: servicos,
        agendamentoId: agendamentoId,
      ),
    );
  }
}

class _GerenciarPacotesView extends StatelessWidget {
  final String clienteId;
  final String clienteNome;
  final List<Map<String, dynamic>> servicos;
  final String? agendamentoId;

  const _GerenciarPacotesView({
    required this.clienteId,
    required this.clienteNome,
    required this.servicos,
    this.agendamentoId,
  });

  void _abrirNovoPacote(BuildContext context) {
    final cubit = context.read<PacotesCubit>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => NovoPacoteDialog(
        clienteId: clienteId,
        clienteNome: clienteNome,
        servicos: servicos,
        onSalvar: cubit.contratarPacote,
      ),
    );
  }

  void _darBaixaSessao(BuildContext context, pacotesState, pacote) {
    final cubit = context.read<PacotesCubit>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DarBaixaSessaoDialog(
        pacote: pacote,
        clienteNome: clienteNome,
        profissionais: pacotesState.profissionais,
        agendamentoId: agendamentoId,
        onConfirmar: cubit.darBaixaSessao,
      ),
    );
  }

  void _verHistorico(BuildContext context, pacote) {
    showDialog(
      context: context,
      builder: (_) => HistoricoSessoesDialog(
        pacote: pacote,
        clienteNome: clienteNome,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return BlocConsumer<PacotesCubit, PacotesState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Colors.red.shade700,
            ),
          );
        } else if (state.successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.successMessage!),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
      },
      builder: (context, state) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 760,
            height: 640,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.inventory_2_outlined, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Carteira de Pacotes & Tratamentos',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Paciente: $clienteNome • ${state.totalSessoesDisponiveis} sessão(ões) ativa(s)',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _abrirNovoPacote(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Contratar Pacote'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 24),

                if (state.status == PacotesStatus.loading && state.pacotes.isEmpty)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (state.pacotes.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.collections_bookmark_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text(
                            'Este cliente ainda não possui pacotes contratados.',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Contrate pacotes de 5, 10 ou mais sessões para fidelizar o cliente.',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () => _abrirNovoPacote(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Contratar Primeiro Pacote'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: state.pacotes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final pacote = state.pacotes[index];
                        final isAtivo = pacote.hasSaldo;
                        final percentual = pacote.quantidadeTotal > 0
                            ? (pacote.quantidadeConsumida / pacote.quantidadeTotal).clamp(0.0, 1.0)
                            : 0.0;

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isAtivo ? AppColors.primary.withValues(alpha: 0.4) : Colors.grey.shade300,
                              width: isAtivo ? 1.5 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isAtivo ? Colors.green.shade50 : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isAtivo ? Colors.green.shade300 : Colors.grey.shade400,
                                      ),
                                    ),
                                    child: Text(
                                      isAtivo ? 'ATIVO' : pacote.status,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isAtivo ? Colors.green.shade800 : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      pacote.tituloExibicao,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                  ),
                                  Text(
                                    currencyFormat.format(pacote.valorTotal),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Barra de progresso
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: percentual,
                                        minHeight: 6,
                                        backgroundColor: Colors.grey.shade200,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          isAtivo ? AppColors.primary : Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '${pacote.quantidadeConsumida}/${pacote.quantidadeTotal} sessões',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.monetization_on_outlined, size: 14, color: Colors.grey.shade600),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${currencyFormat.format(pacote.valorPorSessao)} / sessão',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade600),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Adquirido: ${DateFormat('dd/MM/yyyy').format(pacote.dataAquisicao)}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => _verHistorico(context, pacote),
                                        icon: const Icon(Icons.history, size: 16),
                                        label: Text('Histórico (${pacote.sessoes.length})'),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isAtivo ? Colors.green.shade700 : Colors.grey.shade400,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        ),
                                        onPressed: isAtivo
                                            ? () => _darBaixaSessao(context, state, pacote)
                                            : null,
                                        icon: const Icon(Icons.check, size: 16),
                                        label: const Text('Realizar Sessão'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
