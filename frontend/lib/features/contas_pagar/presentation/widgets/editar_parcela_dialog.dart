import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/moeda_input_formatter.dart';

class EditarParcelaDialog extends StatefulWidget {
  final Map<String, dynamic> parcela;
  final Future<bool> Function({
    required String transacaoId,
    required String novaDataVencimentoStr,
    double? novoValor,
    String? novaDescricao,
    String? novaCategoriaId,
    required bool aplicarEmTodasSeguintes,
  }) onSalvar;

  const EditarParcelaDialog({
    super.key,
    required this.parcela,
    required this.onSalvar,
  });

  @override
  State<EditarParcelaDialog> createState() => _EditarParcelaDialogState();
}

class _EditarParcelaDialogState extends State<EditarParcelaDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _descricaoController;
  late final TextEditingController _vencimentoController;
  late final TextEditingController _valorController;

  late final String _transacaoId;
  late final String _dataVencOriginal;
  late final double _valorOriginal;
  late final bool _isParcelada;
  late final int _totalParcelas;
  late final int _parcelaAtual;

  bool _isSalvando = false;

  @override
  void initState() {
    super.initState();
    final p = widget.parcela;
    _transacaoId = (p['transacao_id'] ?? p['id']).toString();
    final desc = p['descricao']?.toString() ?? 'Despesa';
    _descricaoController = TextEditingController(text: desc);

    _dataVencOriginal = p['data_vencimento']?.toString() ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    _vencimentoController = TextEditingController(text: _dataVencOriginal);

    final rawVal = p['valor_total'] ?? p['valor_parcela'] ?? p['valor'];
    _valorOriginal = (rawVal as num?)?.toDouble() ?? 0.0;
    _valorController = TextEditingController(
      text: NumberFormat.currency(locale: 'pt_BR', symbol: '').format(_valorOriginal).trim(),
    );

    final totP = (p['parcelas'] ?? p['total_parcelas'] as num?)?.toInt() ?? 1;
    final match = RegExp(r'\((\d+)/(\d+)\)').firstMatch(desc);
    if (match != null) {
      _parcelaAtual = int.tryParse(match.group(1)!) ?? 1;
      _totalParcelas = int.tryParse(match.group(2)!) ?? totP;
      _isParcelada = true;
    } else {
      _parcelaAtual = (p['numero_parcela'] as num?)?.toInt() ?? 1;
      _totalParcelas = totP;
      _isParcelada = _totalParcelas > 1 || p['grupo_parcela_id'] != null;
    }
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _vencimentoController.dispose();
    _valorController.dispose();
    super.dispose();
  }

  Future<void> _selecionarDataVencimento() async {
    DateTime dataInicial = DateTime.tryParse(_vencimentoController.text.trim()) ?? DateTime.now();
    final selecionada = await showDatePicker(
      context: context,
      initialDate: dataInicial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'SELECIONE A NOVA DATA DE VENCIMENTO',
      cancelText: 'CANCELAR',
      confirmText: 'CONFIRMAR',
    );
    if (selecionada != null) {
      setState(() {
        _vencimentoController.text = DateFormat('yyyy-MM-dd').format(selecionada);
      });
    }
  }

  Future<void> _submeter() async {
    if (!_formKey.currentState!.validate()) return;

    final novaDataVenc = _vencimentoController.text.trim();
    final novoValor = MoedaInputFormatter.parse(_valorController.text);
    final novaDesc = _descricaoController.text.trim();

    final alterouVencimento = novaDataVenc != _dataVencOriginal;
    final alterouValor = (novoValor - _valorOriginal).abs() > 0.001;

    bool aplicarEmTodas = false;

    // Se faz parte de compra parcelada e o usuário alterou vencimento ou valor:
    if (_isParcelada && (alterouVencimento || alterouValor)) {
      final escolha = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.alt_route, color: AppColors.primary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Aplicar Alteração',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                alterouVencimento
                    ? 'Você alterou o vencimento da parcela $_parcelaAtual de $_totalParcelas de $_dataVencOriginal para $novaDataVenc.'
                    : 'Você alterou os dados da parcela $_parcelaAtual de $_totalParcelas.',
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimaryLight),
              ),
              const SizedBox(height: 16),
              const Text(
                'Como deseja aplicar esta alteração?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => Navigator.pop(ctx, 'SOMENTE_ESTA'),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.looks_one, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Somente nesta parcela',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Modifica apenas a data desta parcela. As demais permanecem inalteradas.',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () => Navigator.pop(ctx, 'TODAS_SEGUINTES'),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade300),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.low_priority, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nesta e em todas as seguintes',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue.shade900),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Desloca proporcionalmente (+ meses/dias) todas as parcelas subsequentes desta compra.',
                              style: TextStyle(fontSize: 11, color: Colors.blue.shade800),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      );

      if (escolha == null) return; // Usuário cancelou
      aplicarEmTodas = escolha == 'TODAS_SEGUINTES';
    }

    setState(() => _isSalvando = true);

    final sucesso = await widget.onSalvar(
      transacaoId: _transacaoId,
      novaDataVencimentoStr: novaDataVenc,
      novoValor: novoValor,
      novaDescricao: novaDesc,
      aplicarEmTodasSeguintes: aplicarEmTodas,
    );

    if (mounted) {
      setState(() => _isSalvando = false);
      if (sucesso) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.edit_calendar, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Editar Parcela / Despesa',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            if (_isParcelada)
                              Text(
                                'Parcela $_parcelaAtual de $_totalParcelas',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                              ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Card de Alerta se for Parcela
                if (_isParcelada)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber.shade900, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Esta despesa faz parte de uma compra parcelada ($_parcelaAtual/$_totalParcelas). Se você alterar a data, o sistema perguntará se quer mover apenas esta ou propagar para as próximas parcelas.',
                            style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Descrição
                TextFormField(
                  controller: _descricaoController,
                  decoration: const InputDecoration(
                    labelText: 'Descrição / Identificação *',
                    prefixIcon: Icon(Icons.receipt_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe a descrição.' : null,
                ),

                const SizedBox(height: 14),

                // Data de Vencimento com DatePicker
                TextFormField(
                  controller: _vencimentoController,
                  readOnly: true,
                  onTap: _selecionarDataVencimento,
                  decoration: InputDecoration(
                    labelText: 'Data de Vencimento *',
                    hintText: 'AAAA-MM-DD',
                    prefixIcon: const Icon(Icons.calendar_month),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.date_range, color: AppColors.primary),
                      onPressed: _selecionarDataVencimento,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe a data de vencimento.' : null,
                ),

                const SizedBox(height: 14),

                // Valor da Parcela
                TextFormField(
                  controller: _valorController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    MoedaInputFormatter(),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Valor da Parcela (R\$) *',
                    hintText: '0,00',
                    prefixIcon: Icon(Icons.attach_money),
                    prefixText: 'R\$ ',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final n = MoedaInputFormatter.parse(v ?? '');
                    if (n <= 0) return 'Informe um valor válido.';
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // Botões de Ação
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSalvando ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSalvando ? null : _submeter,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: _isSalvando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Salvar Alterações',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
