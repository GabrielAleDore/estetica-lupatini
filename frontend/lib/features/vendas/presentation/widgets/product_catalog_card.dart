import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/models/produto_servico_item.dart';

class ProductCatalogCard extends StatelessWidget {
  final ProdutoServicoItem item;
  final VoidCallback onAdd;

  const ProductCatalogCard({
    super.key,
    required this.item,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final isServico = item.tipo == TipoCatalogo.servico;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: item.isSemEstoque
              ? AppColors.error.withValues(alpha: 0.3)
              : AppColors.borderLight,
        ),
      ),
      child: InkWell(
        onTap: item.isSemEstoque ? null : onAdd,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isServico
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : AppColors.pjClinical.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isServico ? Icons.spa_outlined : Icons.inventory_2_outlined,
                      size: 20,
                      color: isServico ? AppColors.primary : AppColors.pjClinical,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (item.codigoSequencial != null)
                              Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.borderLight),
                                ),
                                child: Text(
                                  '#${item.codigoSequencial}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    color: AppColors.textSecondaryLight,
                                  ),
                                ),
                              ),
                            if (item.isPromocaoAtiva)
                              Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.orange.shade300),
                                ),
                                child: const Text(
                                  'PROMO',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    color: Colors.deepOrange,
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Text(
                                item.nome,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isServico
                              ? '${item.duracaoMinutos} min • Procedimento'
                              : 'Estoque: ${item.estoqueAtual.toStringAsFixed(0)} ${item.unidadeMedida}',
                          style: TextStyle(
                            fontSize: 12,
                            color: item.isEstoqueBaixo
                                ? AppColors.error
                                : AppColors.textSecondaryLight,
                            fontWeight: item.isEstoqueBaixo ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (item.isPromocaoAtiva)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currencyFormat.format(item.preco),
                          style: const TextStyle(
                            fontSize: 11,
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          currencyFormat.format(item.precoPromocional),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.deepOrange,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      currencyFormat.format(item.preco),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: item.isSemEstoque ? Colors.grey : AppColors.primaryDark,
                      ),
                    ),
                  ElevatedButton(
                    onPressed: item.isSemEstoque ? null : onAdd,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: item.isPromocaoAtiva ? Colors.deepOrange : AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: const Size(36, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Icon(Icons.add_shopping_cart, size: 16),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
