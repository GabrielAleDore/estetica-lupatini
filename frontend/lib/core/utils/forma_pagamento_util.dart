import 'package:flutter/material.dart';

/// Formas de pagamento/recebimento usadas em despesas e receitas.
class FormaPagamentoUtil {
  static const Map<String, String> _labels = {
    'PIX': 'PIX',
    'DINHEIRO': 'Dinheiro',
    'CARTAO_CREDITO': 'Cartão de Crédito',
    'CARTAO_DEBITO': 'Cartão de Débito',
    'BOLETO': 'Boleto',
    'TRANSFERENCIA': 'Transferência',
    'OUTROS': 'Outros',
  };

  static const List<String> codigosDespesa = [
    'PIX',
    'DINHEIRO',
    'CARTAO_DEBITO',
    'CARTAO_CREDITO',
    'BOLETO',
    'TRANSFERENCIA',
  ];

  static const List<String> codigosReceita = [
    'PIX',
    'DINHEIRO',
    'CARTAO_CREDITO',
    'CARTAO_DEBITO',
    'TRANSFERENCIA',
    'BOLETO',
    'OUTROS',
  ];

  static String label(String? codigo) {
    if (codigo == null || codigo.isEmpty) return '';
    final up = codigo.toUpperCase();
    return _labels[up] ?? codigo;
  }

  static IconData icone(String? codigo) {
    switch (codigo?.toUpperCase()) {
      case 'PIX':
        return Icons.pix;
      case 'DINHEIRO':
        return Icons.payments_outlined;
      case 'CARTAO_CREDITO':
      case 'CARTAO_DEBITO':
        return Icons.credit_card;
      case 'BOLETO':
        return Icons.receipt_long_outlined;
      case 'TRANSFERENCIA':
        return Icons.swap_horiz;
      default:
        return Icons.more_horiz;
    }
  }

  static List<DropdownMenuItem<String>> itens(List<String> codigos) {
    return codigos
        .map((c) => DropdownMenuItem<String>(
              value: c,
              child: Row(
                children: [
                  Icon(icone(c), size: 16, color: Colors.grey.shade700),
                  const SizedBox(width: 8),
                  Text(label(c)),
                ],
              ),
            ))
        .toList();
  }
}
