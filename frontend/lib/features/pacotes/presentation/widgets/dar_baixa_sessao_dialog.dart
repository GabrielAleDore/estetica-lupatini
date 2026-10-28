import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/models/cliente_pacote_model.dart';

class DarBaixaSessaoDialog extends StatefulWidget {
  final ClientePacoteModel pacote;
  final String clienteNome;
  final List<Map<String, dynamic>> profissionais;
  final String? agendamentoId;
  final Future<bool> Function({
    required String pacoteId,
    String? profissionalId,
    String? agendamentoId,
    String? observacoesEvolucao,
    Map<String, dynamic>? parametrosUtilizados,
  }) onConfirmar;

  const DarBaixaSessaoDialog({
    super.key,
    required this.pacote,
    required this.clienteNome,
    required this.profissionais,
    this.agendamentoId,
    required this.onConfirmar,
  });

  @override
  State<DarBaixaSessaoDialog> createState() => _DarBaixaSessaoDialogState();
}

class _DarBaixaSessaoDialogState extends State<DarBaixaSessaoDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _profissionalId;
  final _obsEvolucaoController = TextEditingController();
  final _parametrosController = TextEditingController();
  bool _salvando = false;

  @override
  void dispose() {
    _obsEvolucaoController.dispose();
    _parametrosController.dispose();
    super.dispose();
  }

  Future<void> _submeter() async {
    if (!_formKey.currentState!.validate()) return;

    Map<String, dynamic> params = {};
    if (_parametrosController.text.trim().isNotEmpty) {
      params['descricao_tecnica'] = _parametrosController.text.trim();
    }

    setState(() => _salvando = true);
    final ok = await widget.onConfirmar(
      pacoteId: widget.pacote.id,
      profissionalId: _profissionalId,
      agendamentoId: widget.agendamentoId,
      observacoesEvolucao: _obsEvolucaoController.text.trim().isEmpty
          ? null
          : _obsEvolucaoController.text.trim(),
      parametrosUtilizados: params,
    );

    if (mounted) {
      setState(() => _salvando = false);
      if (ok) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final proximaSessao = widget.pacote.quantidadeConsumida + 1;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.check_circle_outline, color: Colors.green),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Registrar Sessão $proximaSessao de ${widget.pacote.quantidadeTotal}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${widget.pacote.servicoNome} • ${widget.clienteNome}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
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

              // Banner de Saldo
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Após esta confirmação, restarão ${widget.pacote.quantidadeRestante - 1} sessões disponíveis.',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Profissional Executante
              DropdownButtonFormField<String>(
                initialValue: _profissionalId,
                decoration: const InputDecoration(
                  labelText: 'Profissional Executante (Comissão/Auditoria)',
                  prefixIcon: Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(),
                ),
                items: widget.profissionais.map((p) {
                  return DropdownMenuItem<String>(
                    value: p['id'].toString(),
                    child: Text('${p['nome']} (${p['role'] ?? 'Colaborador'})'),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _profissionalId = val),
              ),
              const SizedBox(height: 16),

              // Parâmetros Técnicos Utilizados
              TextFormField(
                controller: _parametrosController,
                decoration: const InputDecoration(
                  labelText: 'Parâmetros Técnicos Utilizados (Opcional)',
                  hintText: 'Ex: Joules: 16, Disparos: 200, Ponteira 3.0mm, Ampola 2ml',
                  prefixIcon: Icon(Icons.tune),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Evolução Clínica / Observações
              TextFormField(
                controller: _obsEvolucaoController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Evolução Clínica & Reações da Paciente',
                  hintText: 'Ex: Procedimento realizado sem queixas. Pele com eritema leve esperado.',
                  prefixIcon: Icon(Icons.assignment_turned_in_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _salvando ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _salvando ? null : _submeter,
                    icon: _salvando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check),
                    label: Text(_salvando ? 'Debitando...' : 'Confirmar Realização'),
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
