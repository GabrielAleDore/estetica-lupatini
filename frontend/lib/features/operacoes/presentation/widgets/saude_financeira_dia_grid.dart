import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/models/cockpit_data.dart';

class SaudeFinanceiraDiaGrid extends StatelessWidget {
  final SaudeFinanceiraDia saude;
  final VoidCallback onVerReceberHoje;
  final VoidCallback onVerPagarHoje;
  final VoidCallback onVerRecebimentosVencidos;
  final VoidCallback onVerPagamentosVencidos;

  const SaudeFinanceiraDiaGrid({
    super.key,
    required this.saude,
    required this.onVerReceberHoje,
    required this.onVerPagarHoje,
    required this.onVerRecebimentosVencidos,
    required this.onVerPagamentosVencidos,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho da Seção
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.monitor_heart_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saúde Financeira do Dia',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Acompanhamento em tempo real de entradas e saídas programadas e pendências',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 4 Cards Responsivos
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 850;
              final isTablet = constraints.maxWidth > 500;

              final cardReceberHoje = _MetricaCard(
                titulo: 'A RECEBER HOJE',
                valor: currencyFormat.format(saude.aReceberHoje),
                detalhe: '${saude.qtdAReceberHoje} ${saude.qtdAReceberHoje == 1 ? "título previsto" : "títulos previstos"}',
                icone: Icons.arrow_circle_up_rounded,
                cor: const Color(0xFF2E7D32),
                fundo: const Color(0xFFE8F5E9),
                onTap: onVerReceberHoje,
              );

              final cardPagarHoje = _MetricaCard(
                titulo: 'A PAGAR HOJE',
                valor: currencyFormat.format(saude.aPagarHoje),
                detalhe: '${saude.qtdAPagarHoje} ${saude.qtdAPagarHoje == 1 ? "conta agendada" : "contas agendadas"}',
                icone: Icons.arrow_circle_down_rounded,
                cor: const Color(0xFFD48B47),
                fundo: const Color(0xFFFFF3E0),
                onTap: onVerPagarHoje,
              );

              final cardReceberVencidos = _MetricaCard(
                titulo: 'RECEBIMENTOS VENCIDOS',
                valor: currencyFormat.format(saude.recebimentosVencidos),
                detalhe: '${saude.qtdRecebimentosVencidos} ${saude.qtdRecebimentosVencidos == 1 ? "venda pendente" : "vendas pendentes"}',
                icone: Icons.pending_actions_rounded,
                cor: const Color(0xFFE65100),
                fundo: const Color(0xFFFFF3E0),
                onTap: onVerRecebimentosVencidos,
              );

              final cardPagarVencidos = _MetricaCard(
                titulo: 'PAGAMENTOS VENCIDOS',
                valor: currencyFormat.format(saude.pagamentosVencidos),
                detalhe: '${saude.qtdPagamentosVencidos} ${saude.qtdPagamentosVencidos == 1 ? "conta em atraso" : "contas em atraso"}',
                icone: Icons.warning_amber_rounded,
                cor: const Color(0xFFC62828),
                fundo: const Color(0xFFFFEBEE),
                onTap: onVerPagamentosVencidos,
              );

              if (isDesktop) {
                return Row(
                  children: [
                    Expanded(child: cardReceberHoje),
                    const SizedBox(width: 14),
                    Expanded(child: cardPagarHoje),
                    const SizedBox(width: 14),
                    Expanded(child: cardReceberVencidos),
                    const SizedBox(width: 14),
                    Expanded(child: cardPagarVencidos),
                  ],
                );
              }

              if (isTablet) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: cardReceberHoje),
                        const SizedBox(width: 14),
                        Expanded(child: cardPagarHoje),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: cardReceberVencidos),
                        const SizedBox(width: 14),
                        Expanded(child: cardPagarVencidos),
                      ],
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  cardReceberHoje,
                  const SizedBox(height: 10),
                  cardPagarHoje,
                  const SizedBox(height: 10),
                  cardReceberVencidos,
                  const SizedBox(height: 10),
                  cardPagarVencidos,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MetricaCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final String detalhe;
  final IconData icone;
  final Color cor;
  final Color fundo;
  final VoidCallback onTap;

  const _MetricaCard({
    required this.titulo,
    required this.valor,
    required this.detalhe,
    required this.icone,
    required this.cor,
    required this.fundo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cor.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: cor.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
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
                  titulo,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: cor,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: fundo, shape: BoxShape.circle),
                  child: Icon(icone, color: cor, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              valor,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: cor,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    detalhe,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ),
                Icon(Icons.open_in_new, size: 11, color: cor.withValues(alpha: 0.7)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
