import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Formatador de entrada de texto para valores monetários em Real (BRL).
/// Converte dinamicamente dígitos digitados em formato monetário (ex: 11111 -> 111,11).
class MoedaInputFormatter extends TextInputFormatter {
  MoedaInputFormatter({this.maxDigitos = 12});

  final int maxDigitos;

  static final NumberFormat _formatter = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: '',
    decimalDigits: 2,
  );

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    String digitos = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (digitos.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final intValor = int.tryParse(digitos) ?? 0;

    // Se o usuário está apagando e o valor virou 0, limpa o campo
    if (intValor == 0 && newValue.text.length < oldValue.text.length) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    if (digitos.length > maxDigitos) {
      digitos = digitos.substring(0, maxDigitos);
    }

    final double valor = intValor / 100.0;
    final novoTexto = _formatter.format(valor).trim();

    return TextEditingValue(
      text: novoTexto,
      selection: TextSelection.collapsed(offset: novoTexto.length),
    );
  }

  /// Converte texto formatado ou qualquer string monetária para double com precisão
  static double parse(String? texto) {
    if (texto == null || texto.trim().isEmpty) return 0.0;
    final limpo = texto.trim();

    // Se possui vírgula (ex: "1.234,56" ou "1234,56")
    if (limpo.contains(',')) {
      final s = limpo.replaceAll(RegExp(r'[^\d,]'), '').replaceAll(',', '.');
      return double.tryParse(s) ?? 0.0;
    }

    // Se possui apenas ponto ou dígitos (ex: "1234.56" ou "1234")
    final s = limpo.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(s) ?? 0.0;
  }

  /// Formata double para texto sem símbolo (ex: 1234.56 -> "1.234,56")
  static String formatar(double valor) {
    if (valor == 0.0) return '0,00';
    return _formatter.format(valor).trim();
  }

  /// Formata double com símbolo R$ (ex: 1234.56 -> "R$ 1.234,56")
  static String formatarComSimbolo(double valor) {
    final f = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 2);
    return f.format(valor).trim();
  }
}
