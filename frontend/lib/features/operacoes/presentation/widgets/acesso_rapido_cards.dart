import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class AcessoRapidoCards extends StatelessWidget {
  final VoidCallback onNovoAgendamento;
  final VoidCallback onNovoCliente;
  final VoidCallback onNovaVenda;
  final VoidCallback onNovaDespesa;

  const AcessoRapidoCards({
    super.key,
    required this.onNovoAgendamento,
    required this.onNovoCliente,
    required this.onNovaVenda,
    required this.onNovaDespesa,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;
        final isTablet = constraints.maxWidth > 600;

        final cardAgendamento = _AcaoCard(
          titulo: 'Novo Agendamento',
          subtitulo: 'Marcar horário na agenda',
          icone: Icons.calendar_month,
          cor: AppColors.primary,
          fundo: AppColors.primarySubtle,
          onTap: onNovoAgendamento,
        );

        final cardCliente = _AcaoCard(
          titulo: 'Novo Cliente',
          subtitulo: 'Cadastrar ficha e anamnese',
          icone: Icons.person_add_alt_1,
          cor: const Color(0xFF1565C0),
          fundo: const Color(0xFFE3F2FD),
          onTap: onNovoCliente,
        );

        final cardVenda = _AcaoCard(
          titulo: 'Nova Venda (PDV)',
          subtitulo: 'Iniciar atendimento no caixa',
          icone: Icons.point_of_sale,
          cor: const Color(0xFF2E7D32),
          fundo: const Color(0xFFE8F5E9),
          onTap: onNovaVenda,
        );

        final cardDespesa = _AcaoCard(
          titulo: 'Nova Despesa',
          subtitulo: 'Lançar conta a pagar / custo',
          icone: Icons.post_add,
          cor: const Color(0xFFD48B47),
          fundo: const Color(0xFFFFF3E0),
          onTap: onNovaDespesa,
        );

        if (isDesktop) {
          return Row(
            children: [
              Expanded(child: cardAgendamento),
              const SizedBox(width: 14),
              Expanded(child: cardCliente),
              const SizedBox(width: 14),
              Expanded(child: cardVenda),
              const SizedBox(width: 14),
              Expanded(child: cardDespesa),
            ],
          );
        }

        if (isTablet) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: cardAgendamento),
                  const SizedBox(width: 14),
                  Expanded(child: cardCliente),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: cardVenda),
                  const SizedBox(width: 14),
                  Expanded(child: cardDespesa),
                ],
              ),
            ],
          );
        }

        return Column(
          children: [
            cardAgendamento,
            const SizedBox(height: 10),
            cardCliente,
            const SizedBox(height: 10),
            cardVenda,
            const SizedBox(height: 10),
            cardDespesa,
          ],
        );
      },
    );
  }
}

class _AcaoCard extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final IconData icone;
  final Color cor;
  final Color fundo;
  final VoidCallback onTap;

  const _AcaoCard({
    required this.titulo,
    required this.subtitulo,
    required this.icone,
    required this.cor,
    required this.fundo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: fundo,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icone, color: cor, size: 22),
            ),
            const SizedBox(width: 12),
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
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: cor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 12, color: cor.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}
