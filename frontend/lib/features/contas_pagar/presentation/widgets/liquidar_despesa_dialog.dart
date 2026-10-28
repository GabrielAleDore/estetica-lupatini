import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/moeda_input_formatter.dart';
import '../../../contas_bancarias/domain/models/conta_bancaria_model.dart';

class LiquidarDespesaDialog extends StatefulWidget {
  final Map<String, dynamic> despesa;
  final List<ContaBancariaModel> contasBancarias;
  final Future<void> Function({
    required String transacaoId,
    String? contaBancariaId,
    required DateTime dataPagamento,
    double? valorFinal,
    String? comprovante,
    String? observacoes,
  }) onConfirmar;

  const LiquidarDespesaDialog({
    super.key,
    required this.despesa,
    required this.contasBancarias,
    required this.onConfirmar,
  });

  @override
  State<LiquidarDespesaDialog> createState() => _LiquidarDespesaDialogState();
}

class _LiquidarDespesaDialogState extends State<LiquidarDespesaDialog> {
  final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _dateFormat = DateFormat('dd/MM/yyyy');

  late DateTime _dataPagamento;
  String? _contaSelecionadaId;
  final _jurosMultaController = TextEditingController();
  final _descontoController = TextEditingController();
  final _comprovanteController = TextEditingController();
  final _obsController = TextEditingController();
  bool _salvando = false;

  late double _valorNominal;
  DateTime? _dataVencimento;

  @override
  void initState() {
    super.initState();
    _dataPagamento = DateTime.now();

    _valorNominal = (widget.despesa['valor_total'] as num?)?.toDouble() ??
        (widget.despesa['valor'] as num?)?.toDouble() ??
        0.0;

    final vencStr = widget.despesa['data_vencimento']?.toString();
    if (vencStr != null && vencStr.isNotEmpty) {
      _dataVencimento = DateTime.tryParse(vencStr);
    }

    final contaOrigem = widget.despesa['conta_bancaria_id']?.toString();
    if (contaOrigem != null && widget.contasBancarias.any((c) => c.id == contaOrigem)) {
      _contaSelecionadaId = contaOrigem;
    } else if (widget.contasBancarias.isNotEmpty) {
      _contaSelecionadaId = widget.contasBancarias.first.id;
    }
  }

  @override
  void dispose() {
    _jurosMultaController.dispose();
    _descontoController.dispose();
    _comprovanteController.dispose();
    _obsController.dispose();
    super.dispose();
  }

  double _obterValorAjustado() {
    double valor = _valorNominal;

    final jurosStr = _jurosMultaController.text.replaceAll('.', '').replaceAll(',', '.').trim();
    final juros = double.tryParse(jurosStr) ?? 0.0;
    valor += juros;

    final descStr = _descontoController.text.replaceAll('.', '').replaceAll(',', '.').trim();
    final desc = double.tryParse(descStr) ?? 0.0;
    valor -= desc;

    return valor > 0 ? valor : 0.0;
  }

  Future<void> _selecionarData(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataPagamento,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('pt', 'BR'),
      helpText: 'SELECIONE A DATA DA EFETIVAÇÃO DO PAGAMENTO',
      cancelText: 'CANCELAR',
      confirmText: 'CONFIRMAR DATA',
    );

    if (picked != null) {
      setState(() => _dataPagamento = picked);
    }
  }

  void _definirData(DateTime data) {
    setState(() => _dataPagamento = data);
  }

  Future<void> _submeter() async {
    final id = widget.despesa['id']?.toString();
    if (id == null) return;

    final valorFinal = _obterValorAjustado();

    setState(() => _salvando = true);
    try {
      await widget.onConfirmar(
        transacaoId: id,
        contaBancariaId: _contaSelecionadaId,
        dataPagamento: _dataPagamento,
        valorFinal: valorFinal,
        comprovante: _comprovanteController.text.trim().isEmpty ? null : _comprovanteController.text.trim(),
        observacoes: _obsController.text.trim().isEmpty ? null : _obsController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final desc = widget.despesa['descricao'] ?? 'Obrigação / Despesa';
    final categoria = widget.despesa['categoria']?['nome'] ?? widget.despesa['categoria_nome'] ?? 'Geral';
    final valorFinal = _obterValorAjustado();
    final hoje = DateTime.now();
    final ehHoje = _dataPagamento.year == hoje.year &&
        _dataPagamento.month == hoje.month &&
        _dataPagamento.day == hoje.day;
    final ehRetroativo = _dataPagamento.isBefore(DateTime(hoje.year, hoje.month, hoje.day));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 540,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho Corporativo
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16293A).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.account_balance_wallet, color: Color(0xFF16293A), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Liquidação Financeira de Título',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF16293A),
                          ),
                        ),
                        Text(
                          'Baixa de obrigação e conciliação bancária',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Resumo do Título / Obrigação
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6F8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            desc,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _currencyFormat.format(_valorNominal),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF16293A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 16,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.category_outlined, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              'Categoria: $categoria',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                        if (_dataVencimento != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                'Vencimento: ${_dateFormat.format(_dataVencimento!)}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 1. DATA EFETIVA DO PAGAMENTO (Com suporte retroativo e atalhos)
              const Text(
                '1. Data Efetiva do Pagamento *',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF16293A)),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        alignment: Alignment.centerLeft,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        side: BorderSide(
                          color: ehRetroativo ? Colors.amber.shade700 : const Color(0xFF16293A),
                          width: 1.2,
                        ),
                      ),
                      onPressed: () => _selecionarData(context),
                      icon: Icon(
                        Icons.calendar_month,
                        color: ehRetroativo ? Colors.amber.shade900 : const Color(0xFF16293A),
                        size: 18,
                      ),
                      label: Text(
                        _dateFormat.format(_dataPagamento),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: ehRetroativo ? Colors.amber.shade900 : const Color(0xFF16293A),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Atalhos Rápidos de Data
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _AtalhoDataChip(
                    label: 'Hoje',
                    selecionado: ehHoje,
                    onTap: () => _definirData(DateTime.now()),
                  ),
                  _AtalhoDataChip(
                    label: 'Ontem',
                    selecionado: _dataPagamento.year == hoje.year &&
                        _dataPagamento.month == hoje.month &&
                        _dataPagamento.day == hoje.day - 1,
                    onTap: () => _definirData(DateTime.now().subtract(const Duration(days: 1))),
                  ),
                  if (_dataVencimento != null)
                    _AtalhoDataChip(
                      label: 'No Vencimento (${_dateFormat.format(_dataVencimento!)})',
                      selecionado: _dataPagamento.year == _dataVencimento!.year &&
                          _dataPagamento.month == _dataVencimento!.month &&
                          _dataPagamento.day == _dataVencimento!.day,
                      onTap: () => _definirData(_dataVencimento!),
                    ),
                ],
              ),

              if (ehRetroativo) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 15, color: Colors.amber.shade900),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Baixa retroativa: a saída de caixa será registrada na data ${_dateFormat.format(_dataPagamento)} para conciliação contábil.',
                          style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),

              // 2. CONTA BANCÁRIA DE SAÍDA (Com exibição de saldo)
              const Text(
                '2. Conta Bancária de Origem do Débito *',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF16293A)),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String?>(
                isExpanded: true,
                initialValue: _contaSelecionadaId,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.account_balance, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Sem débito em conta bancária (Caixa Físico / Outro)', style: TextStyle(fontSize: 13)),
                  ),
                  ...widget.contasBancarias.map((c) {
                    final saldoFmt = _currencyFormat.format(c.saldoAtual);
                    return DropdownMenuItem<String?>(
                      value: c.id,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${c.nomeConta} (${c.bancoNome})',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: c.saldoAtual >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Saldo: $saldoFmt',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: c.saldoAtual >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                onChanged: (val) => setState(() => _contaSelecionadaId = val),
              ),
              const SizedBox(height: 18),

              // 3. AJUSTES FINANCEIROS NA BAIXA (Juros/Multa ou Desconto)
              const Text(
                '3. Ajustes na Baixa (Juros, Multa ou Desconto)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF16293A)),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _jurosMultaController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [MoedaInputFormatter()],
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: '(+) Juros / Multa',
                        prefixText: 'R\$ ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _descontoController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [MoedaInputFormatter()],
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: '(-) Desconto Obtido',
                        prefixText: 'R\$ ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Banner de Valor Final Efetivo
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF16293A).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF16293A).withValues(alpha: 0.2)),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    const Text(
                      'Valor Efetivo da Baixa no Caixa:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF16293A)),
                    ),
                    Text(
                      _currencyFormat.format(valorFinal),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. INFORMAÇÕES DE AUDITORIA & CONCILIAÇÃO
              TextFormField(
                controller: _comprovanteController,
                decoration: const InputDecoration(
                  labelText: 'Nº Comprovante / Autenticação Bancária (Opcional)',
                  hintText: 'Ex: 8FA3.2201.BC99 ou Código Pix',
                  prefixIcon: Icon(Icons.tag, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _obsController,
                decoration: const InputDecoration(
                  labelText: 'Observações Internas da Baixa (Opcional)',
                  hintText: 'Ex: Pago via app bancário no fim de semana',
                  prefixIcon: Icon(Icons.notes, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 24),

              // Ações Finais
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _salvando ? null : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 1,
                    ),
                    onPressed: _salvando ? null : _submeter,
                    icon: _salvando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(
                      _salvando ? 'Liquidando...' : 'Confirmar Liquidação',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
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

class _AtalhoDataChip extends StatelessWidget {
  final String label;
  final bool selecionado;
  final VoidCallback onTap;

  const _AtalhoDataChip({
    required this.label,
    required this.selecionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selecionado ? const Color(0xFF16293A) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selecionado ? const Color(0xFF16293A) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selecionado ? FontWeight.bold : FontWeight.w500,
            color: selecionado ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
