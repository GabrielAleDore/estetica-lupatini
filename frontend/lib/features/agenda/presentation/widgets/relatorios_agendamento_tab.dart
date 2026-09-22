import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class RelatoriosAgendamentoTab extends StatelessWidget {
  final Map<String, dynamic> metricas;
  final VoidCallback onAtualizar;

  const RelatoriosAgendamentoTab({
    super.key,
    required this.metricas,
    required this.onAtualizar,
  });

  @override
  Widget build(BuildContext context) {
    final total = (metricas['total'] as num?)?.toInt() ?? 0;
    final confirmados = (metricas['confirmados'] as num?)?.toInt() ?? 0;
    final concluidos = (metricas['concluidos'] as num?)?.toInt() ?? 0;
    final cancelados = (metricas['cancelados'] as num?)?.toInt() ?? 0;
    final noShows = (metricas['no_shows'] as num?)?.toInt() ?? 0;
    final agendados = (metricas['agendados'] as num?)?.toInt() ?? 0;
    final taxaComparecimento = (metricas['taxa_comparecimento'] as num?)?.toDouble() ?? 0.0;
    final taxaConfirmacao = (metricas['taxa_confirmacao'] as num?)?.toDouble() ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Relatório de Performance da Agenda',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Análise de comparecimento, confirmações de WhatsApp, cancelamentos e no-shows',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: onAtualizar,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Atualizar Métricas'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 2 Cards Principais de Taxas
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              final cards = [
                _buildTaxaCard(
                  titulo: 'Taxa de Comparecimento',
                  percentual: taxaComparecimento,
                  subtitulo: '$concluidos concluídos de ${concluidos + cancelados + noShows} finalizados',
                  icone: Icons.verified_user_outlined,
                  cor: const Color(0xFF2E7D32),
                  bgCor: const Color(0xFFE8F5E9),
                ),
                _buildTaxaCard(
                  titulo: 'Taxa de Confirmação',
                  percentual: taxaConfirmacao,
                  subtitulo: '${confirmados + concluidos} confirmaram de $total marcados',
                  icone: Icons.mark_chat_read_outlined,
                  cor: const Color(0xFF1976D2),
                  bgCor: const Color(0xFFE3F2FD),
                ),
              ];

              if (!isWide) {
                return Column(
                  children: [
                    cards[0],
                    const SizedBox(height: 16),
                    cards[1],
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 16),
                  Expanded(child: cards[1]),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Cards de Contagem
          const Text(
            'Distribuição de Atendimentos',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildContagemCard('Total Agendados', total.toString(), Icons.event_note, Colors.blueGrey),
              _buildContagemCard('Confirmados', confirmados.toString(), Icons.check_circle_outline, const Color(0xFF1976D2)),
              _buildContagemCard('Concluídos (Atendidos)', concluidos.toString(), Icons.task_alt, const Color(0xFF2E7D32)),
              _buildContagemCard('Cancelamentos', cancelados.toString(), Icons.cancel_outlined, Colors.red.shade600),
              _buildContagemCard('No-Shows (Faltas)', noShows.toString(), Icons.person_off_outlined, Colors.deepOrange),
              _buildContagemCard('Aguardando Horário', agendados.toString(), Icons.schedule, Colors.grey.shade700),
            ],
          ),
          const SizedBox(height: 28),

          // Barra Visual de Proporção
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Distribuição Percentual de Desfecho',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (total == 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(child: Text('Nenhum agendamento registrado no período.', style: TextStyle(color: Colors.grey))),
                    )
                  else ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        height: 24,
                        child: Row(
                          children: [
                            if (concluidos > 0)
                              Expanded(
                                flex: concluidos,
                                child: Container(color: const Color(0xFF2E7D32)),
                              ),
                            if (confirmados > 0)
                              Expanded(
                                flex: confirmados,
                                child: Container(color: const Color(0xFF1976D2)),
                              ),
                            if (agendados > 0)
                              Expanded(
                                flex: agendados,
                                child: Container(color: Colors.blueGrey.shade300),
                              ),
                            if (cancelados > 0)
                              Expanded(
                                flex: cancelados,
                                child: Container(color: Colors.red.shade400),
                              ),
                            if (noShows > 0)
                              Expanded(
                                flex: noShows,
                                child: Container(color: Colors.deepOrange.shade400),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _buildLegendaItem('Concluídos', const Color(0xFF2E7D32), concluidos, total),
                        _buildLegendaItem('Confirmados', const Color(0xFF1976D2), confirmados, total),
                        _buildLegendaItem('Aguardando', Colors.blueGrey.shade300, agendados, total),
                        _buildLegendaItem('Cancelados', Colors.red.shade400, cancelados, total),
                        _buildLegendaItem('No-Shows', Colors.deepOrange.shade400, noShows, total),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxaCard({
    required String titulo,
    required double percentual,
    required String subtitulo,
    required IconData icone,
    required Color cor,
    required Color bgCor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: bgCor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icone, color: cor, size: 32),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '${percentual.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: cor),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitulo,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContagemCard(String label, String valor, IconData icone, Color cor) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: cor, size: 22),
          const SizedBox(height: 10),
          Text(
            valor,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: cor),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendaItem(String label, Color cor, int count, int total) {
    final pct = total > 0 ? (count / total * 100).toStringAsFixed(1) : '0';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('$label: $count ($pct%)', style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
      ],
    );
  }
}
