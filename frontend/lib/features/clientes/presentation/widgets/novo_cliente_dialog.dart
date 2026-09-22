import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';

class NovoClienteDialog extends StatefulWidget {
  final Future<bool> Function(Map<String, dynamic> dados) onSalvar;
  final String? Function()? getLastError;

  const NovoClienteDialog({
    super.key,
    required this.onSalvar,
    this.getLastError,
  });

  @override
  State<NovoClienteDialog> createState() => _NovoClienteDialogState();
}

class _NovoClienteDialogState extends State<NovoClienteDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _cpfController = TextEditingController();
  final _nascimentoController = TextEditingController();

  // Anamnese
  String _tipoPele = 'Mista';
  String _fototipo = 'III';
  final _alergiasController = TextEditingController();
  final _medicamentosController = TextEditingController();
  final _queixaController = TextEditingController();
  final _obsController = TextEditingController();

  bool _isSalvando = false;
  String? _erroInline;

  @override
  void dispose() {
    _nomeController.dispose();
    _telefoneController.dispose();
    _emailController.dispose();
    _cpfController.dispose();
    _nascimentoController.dispose();
    _alergiasController.dispose();
    _medicamentosController.dispose();
    _queixaController.dispose();
    _obsController.dispose();
    super.dispose();
  }

  Future<void> _selecionarDataNascimento() async {
    DateTime initial = DateTime.now().subtract(const Duration(days: 365 * 25));
    if (_nascimentoController.text.trim().isNotEmpty) {
      try {
        final text = _nascimentoController.text.trim();
        if (text.contains('/')) {
          final parts = text.split('/');
          initial = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        } else if (text.contains('-')) {
          final parts = text.split('-');
          initial = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        }
      } catch (_) {}
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
      helpText: 'SELECIONE A DATA DE NASCIMENTO',
    );

    if (picked != null) {
      setState(() {
        _nascimentoController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _submeter() async {
    setState(() => _erroInline = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSalvando = true);

    final emailLimpo = _emailController.text.trim();
    final cpfLimpo = _cpfController.text.trim();
    final nascimentoLimpo = _nascimentoController.text.trim();

    String? dataNascimentoIso;
    if (nascimentoLimpo.isNotEmpty) {
      try {
        final parts = nascimentoLimpo.split('/');
        if (parts.length == 3) {
          dataNascimentoIso = '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
        } else if (nascimentoLimpo.contains('-')) {
          dataNascimentoIso = nascimentoLimpo;
        }
      } catch (e) {
        dataNascimentoIso = null;
      }
    }

    final dados = {
      'nome': _nomeController.text.trim(),
      'telefone': _telefoneController.text.trim(),
      'email': emailLimpo.isEmpty ? null : emailLimpo,
      'cpf': cpfLimpo.isEmpty ? null : cpfLimpo,
      'data_nascimento': dataNascimentoIso,
      'status': 'ATIVO',
      'anamnese': {
        'tipo_pele': _tipoPele,
        'fototipo_fitzpatrick': _fototipo,
        'alergias': _alergiasController.text.trim().isNotEmpty
            ? _alergiasController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
            : [],
        'medicamentos_uso': _medicamentosController.text.trim().isNotEmpty
            ? _medicamentosController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
            : [],
        'queixa_principal': _queixaController.text.trim().isEmpty ? null : _queixaController.text.trim(),
        'observacoes_tecnicas': _obsController.text.trim().isEmpty ? null : _obsController.text.trim(),
      }
    };

    final sucesso = await widget.onSalvar(dados);
    if (mounted) {
      setState(() => _isSalvando = false);
      if (sucesso) {
        Navigator.of(context).pop();
      } else {
        final err = widget.getLastError?.call();
        setState(() {
          _erroInline = err ?? 'Não foi possível cadastrar o paciente. Verifique os dados e tente novamente.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 750),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.person_add_alt_1, color: AppColors.primaryDark),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Novo Paciente / Cliente',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Cadastre os dados pessoais e a ficha de anamnese',
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Inline Error Banner
                if (_erroInline != null) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _erroInline!,
                            style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16, color: AppColors.error),
                          onPressed: () => setState(() => _erroInline = null),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ],

                // Form Scrollable Body
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Seção 1: Dados Pessoais
                        const Text(
                          '1. Dados Pessoais e Contato',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _nomeController,
                          decoration: const InputDecoration(
                            labelText: 'Nome Completo *',
                            hintText: 'Ex: Mariana Silveira Alcantara',
                            prefixIcon: Icon(Icons.badge_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome do paciente.' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _telefoneController,
                                decoration: const InputDecoration(
                                  labelText: 'Telefone / WhatsApp *',
                                  hintText: '(11) 99999-9999',
                                  prefixIcon: Icon(Icons.phone_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o telefone de contato.' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _cpfController,
                                decoration: const InputDecoration(
                                  labelText: 'CPF (Opcional)',
                                  hintText: '000.000.000-00',
                                  prefixIcon: Icon(Icons.credit_card_outlined),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'E-mail (Opcional)',
                                  hintText: 'paciente@email.com',
                                  prefixIcon: Icon(Icons.email_outlined),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _nascimentoController,
                                decoration: InputDecoration(
                                  labelText: 'Data de Nascimento (Opcional)',
                                  hintText: 'DD/MM/AAAA',
                                  prefixIcon: const Icon(Icons.cake_outlined),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.calendar_today, size: 18),
                                    onPressed: _selecionarDataNascimento,
                                    tooltip: 'Abrir Calendário',
                                  ),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                        // Seção 2: Ficha Dermatológica
                        const Text(
                          '2. Ficha de Anamnese Dermatológica',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: _tipoPele,
                                decoration: const InputDecoration(
                                  labelText: 'Tipo de Pele',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.face),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'Normal', child: Text('Normal')),
                                  DropdownMenuItem(value: 'Seca', child: Text('Seca')),
                                  DropdownMenuItem(value: 'Oleosa', child: Text('Oleosa')),
                                  DropdownMenuItem(value: 'Mista', child: Text('Mista')),
                                  DropdownMenuItem(value: 'Sensível', child: Text('Sensível')),
                                ],
                                onChanged: (v) => setState(() => _tipoPele = v!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: _fototipo,
                                decoration: const InputDecoration(
                                  labelText: 'Fototipo Fitzpatrick',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.wb_sunny_outlined),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'I', child: Text('I - Muito Clara')),
                                  DropdownMenuItem(value: 'II', child: Text('II - Clara')),
                                  DropdownMenuItem(value: 'III', child: Text('III - Morena Clara')),
                                  DropdownMenuItem(value: 'IV', child: Text('IV - Morena Média')),
                                  DropdownMenuItem(value: 'V', child: Text('V - Morena Escura')),
                                  DropdownMenuItem(value: 'VI', child: Text('VI - Negra')),
                                ],
                                onChanged: (v) => setState(() => _fototipo = v!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _alergiasController,
                          decoration: const InputDecoration(
                            labelText: 'Alergias (separadas por vírgula)',
                            hintText: 'Ex: Dipirona, Ácido Retinóico, Látex',
                            prefixIcon: Icon(Icons.warning_amber_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _medicamentosController,
                          decoration: const InputDecoration(
                            labelText: 'Medicamentos em Uso Contínuo',
                            hintText: 'Ex: Roacutan, Anticoncepcional, Anti-hipertensivo',
                            prefixIcon: Icon(Icons.medication_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _queixaController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Queixa Principal / Objetivo Estético',
                            hintText: 'Ex: Linhas de expressão na testa e queixa de flacidez no terço inferior',
                            prefixIcon: Icon(Icons.chat_bubble_outline),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _obsController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Observações Técnicas / Plano de Tratamento',
                            hintText: 'Ex: Paciente com boa hidratação, indicada toxina botulínica e bioestimulador',
                            prefixIcon: Icon(Icons.notes),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Divider(height: 24),
                // Botões de Ação
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSalvando ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isSalvando ? null : _submeter,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                      icon: _isSalvando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _isSalvando ? 'Salvando...' : 'Salvar Paciente',
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
