import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/models/cockpit_data.dart';

class ResumoPeriodoTable extends StatelessWidget {
  final ResumoPeriodo resumo;
  final String periodoLabel;

  const ResumoPeriodoTable({
    super.key,
    required this.resumo,
    this.periodoLabel = 'Mês Vigente',
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final saldo = resumo.saldo;

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
          // Cabeçalho da Tabela
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.table_chart_outlined,
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
                      'Resumo do Período Financeiro',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Demonstrativo consolidado de previsões, pendências e liquidações',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Text(
                  periodoLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Tabela Demonstrativa com Scroll Horizontal em Mobile
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 550),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(2.2), // Fluxo
                  1: FlexColumnWidth(2.0), // Previsto
                  2: FlexColumnWidth(2.0), // Não Pago
                  3: FlexColumnWidth(2.0), // Realizado
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  // Linha de Cabeçalho da Tabela
                  TableRow(
                    decoration: BoxDecoration(
                      color: AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Text(
                          'FLUXO',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondaryLight),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Text(
                          'PREVISTO',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondaryLight),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Text(
                          'NÃO PAGO (PENDENTE)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondaryLight),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Text(
                          'REALIZADO (LIQUIDADO)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondaryLight),
                        ),
                      ),
                    ],
                  ),

                  // Linha: Receber
                  TableRow(
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.borderLight, width: 0.8)),
                    ),
                    children: [
                      _buildCelulaFluxo(
                        'Receber',
                        'Vendas e entradas',
                        Icons.trending_up,
                        const Color(0xFF2E7D32),
                      ),
                      _buildCelulaValor(currencyFormat.format(resumo.receber.previsto), const Color(0xFF2E7D32)),
                      _buildCelulaValor(currencyFormat.format(resumo.receber.naoPago), const Color(0xFFE65100)),
                      _buildCelulaValor(currencyFormat.format(resumo.receber.realizado), const Color(0xFF2E7D32), isBold: true),
                    ],
                  ),

                  // Linha: Pagar
                  TableRow(
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.borderLight, width: 0.8)),
                    ),
                    children: [
                      _buildCelulaFluxo(
                        'Pagar',
                        'Contas e despesas',
                        Icons.trending_down,
                        const Color(0xFFC62828),
                      ),
                      _buildCelulaValor(currencyFormat.format(resumo.pagar.previsto), const Color(0xFFC62828)),
                      _buildCelulaValor(currencyFormat.format(resumo.pagar.naoPago), const Color(0xFFC62828)),
                      _buildCelulaValor(currencyFormat.format(resumo.pagar.realizado), const Color(0xFFC62828), isBold: true),
                    ],
                  ),

                  // Linha: Saldo (Destaque)
                  TableRow(
                    decoration: BoxDecoration(
                      color: (saldo.realizado >= 0 ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE)).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    children: [
                      _buildCelulaFluxo(
                        'Saldo Líquido',
                        'Resultado financeiro',
                        Icons.account_balance_wallet_outlined,
                        saldo.realizado >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                        isDestaque: true,
                      ),
                      _buildCelulaValor(
                        currencyFormat.format(saldo.previsto),
                        saldo.previsto >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                        isBold: true,
                      ),
                      _buildCelulaValor(
                        currencyFormat.format(saldo.naoPago),
                        saldo.naoPago >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                        isBold: true,
                      ),
                      _buildCelulaValor(
                        currencyFormat.format(saldo.realizado),
                        saldo.realizado >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                        isBold: true,
                        fontSize: 14,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCelulaFluxo(String titulo, String subtitulo, IconData icone, Color cor, {bool isDestaque = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Row(
        children: [
          Icon(icone, size: 18, color: cor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isDestaque ? 13 : 12,
                    fontWeight: isDestaque ? FontWeight.w900 : FontWeight.bold,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                Text(
                  subtitulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondaryLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCelulaValor(String valor, Color cor, {bool isBold = false, double fontSize = 13}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(
        valor,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          color: cor,
        ),
      ),
    );
  }
}
