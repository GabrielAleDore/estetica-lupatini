import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';

class NovoAgendamentoDialog extends StatefulWidget {
  final List<Map<String, dynamic>> clientes;
  final List<Map<String, dynamic>> servicos;
  final DateTime dataInicial;
  final Future<bool> Function({
    required String clienteId,
    required String servicoId,
    required DateTime dataHoraInicio,
    required DateTime dataHoraFim,
    String? observacoes,
  }) onSalvar;

  const NovoAgendamentoDialog({
    super.key,
    required this.clientes,
    required this.servicos,
    required this.dataInicial,
    required this.onSalvar,
  });

  @override
  State<NovoAgendamentoDialog> createState() => _NovoAgendamentoDialogState();
}

class _NovoAgendamentoDialogState extends State<NovoAgendamentoDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _clienteIdSelecionado;
  String? _servicoIdSelecionado;
  late DateTime _dataSelecionada;
  TimeOfDay _horarioInicio = const TimeOfDay(hour: 9, minute: 0);
  int _duracaoMinutos = 60;
  final _obsController = TextEditingController();
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _dataSelecionada = widget.dataInicial;
    if (widget.clientes.isNotEmpty) {
      _clienteIdSelecionado = widget.clientes.first['id'] as String?;
    }
    if (widget.servicos.isNotEmpty) {
      _servicoIdSelecionado = widget.servicos.first['id'] as String?;
      _duracaoMinutos = (widget.servicos.first['duracao_minutos'] as num?)?.toInt() ?? 60;
    }
  }

  @override
  void dispose() {
    _obsController.dispose();
    super.dispose();
  }

  void _aoMudarServico(String? id) {
    setState(() {
      _servicoIdSelecionado = id;
      if (id != null) {
        final servico = widget.servicos.firstWhere(
          (s) => s['id'] == id,
          orElse: () => {},
        );
        _duracaoMinutos = (servico['duracao_minutos'] as num?)?.toInt() ?? 60;
      }
    });
  }

  DateTime get _inicioCalculado {
    return DateTime(
      _dataSelecionada.year,
      _dataSelecionada.month,
      _dataSelecionada.day,
      _horarioInicio.hour,
      _horarioInicio.minute,
    );
  }

  DateTime get _fimCalculado {
    return _inicioCalculado.add(Duration(minutes: _duracaoMinutos));
  }

  Future<void> _submeter() async {
    if (!_formKey.currentState!.validate()) return;
    if (_clienteIdSelecionado == null || _servicoIdSelecionado == null) return;

    setState(() => _salvando = true);

    final sucesso = await widget.onSalvar(
      clienteId: _clienteIdSelecionado!,
      servicoId: _servicoIdSelecionado!,
      dataHoraInicio: _inicioCalculado,
      dataHoraFim: _fimCalculado,
      observacoes: _obsController.text.trim().isNotEmpty ? _obsController.text.trim() : null,
    );

    if (mounted) {
      setState(() => _salvando = false);
      if (sucesso) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primarySubtle,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add_task, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Novo Agendamento',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Marcar procedimento com duração calculada automaticamente',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
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

                // Seleção de Cliente
                DropdownButtonFormField<String>(
                  initialValue: _clienteIdSelecionado,
                  decoration: InputDecoration(
                    labelText: 'Cliente *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.person, color: AppColors.primary),
                  ),
                  items: widget.clientes.map((c) {
                    final nome = c['nome'] ?? c['nome_completo'] ?? 'Cliente';
                    final tel = c['telefone'] ?? '';
                    final isVip = (c['is_fidelizada'] ?? false) as bool;
                    return DropdownMenuItem<String>(
                      value: c['id'] as String,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              nome,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          if (isVip) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('VIP ⭐', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber)),
                            ),
                          ],
                          if (tel.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text('($tel)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _clienteIdSelecionado = val),
                  validator: (val) => val == null ? 'Selecione uma cliente' : null,
                ),
                const SizedBox(height: 16),

                // Seleção de Serviço (com código, duração e preço)
                DropdownButtonFormField<String>(
                  initialValue: _servicoIdSelecionado,
                  decoration: InputDecoration(
                    labelText: 'Procedimento / Serviço *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.spa, color: AppColors.primary),
                  ),
                  items: widget.servicos.map((s) {
                    final cod = s['codigo_sequencial'] != null ? '#${s['codigo_sequencial']} ' : '';
                    final nome = s['nome'] ?? 'Serviço';
                    final duracao = (s['duracao_minutos'] as num?)?.toInt() ?? 60;
                    final preco = (s['preco'] as num?)?.toDouble() ?? 0.0;
                    final emPromo = (s['em_promocao'] ?? false) as bool;
                    final precoPromo = (s['preco_promocional'] as num?)?.toDouble();

                    return DropdownMenuItem<String>(
                      value: s['id'] as String,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(cod, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13)),
                          Flexible(
                            child: Text(
                              nome,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '($duracao min - ${currencyFormat.format(emPromo && precoPromo != null ? precoPromo : preco)})',
                            style: TextStyle(fontSize: 12, color: emPromo ? Colors.deepOrange : Colors.grey.shade700),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: _aoMudarServico,
                  validator: (val) => val == null ? 'Selecione um serviço' : null,
                ),
                const SizedBox(height: 16),

                // Data e Horário
                Row(
                  children: [
                    // Data
                    Expanded(
                      flex: 3,
                      child: InkWell(
                        onTap: () async {
                          final data = await showDatePicker(
                            context: context,
                            initialDate: _dataSelecionada,
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (data != null) {
                            setState(() => _dataSelecionada = data);
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Data do Agendamento',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            prefixIcon: const Icon(Icons.calendar_today, color: AppColors.primary),
                          ),
                          child: Text(dateFormat.format(_dataSelecionada)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Horário Início
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: () async {
                          final hora = await showTimePicker(
                            context: context,
                            initialTime: _horarioInicio,
                          );
                          if (hora != null) {
                            setState(() => _horarioInicio = hora);
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Início',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            prefixIcon: const Icon(Icons.access_time, color: AppColors.primary),
                          ),
                          child: Text('${_horarioInicio.hour.toString().padLeft(2, '0')}:${_horarioInicio.minute.toString().padLeft(2, '0')}'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Bloco informativo de Horário de Término estimado
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F8E9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFC8E6C9)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 20, color: Color(0xFF2E7D32)),
                      const SizedBox(width: 10),
                      Text(
                        'Duração: $_duracaoMinutos min  •  Término estimado: ${timeFormat.format(_fimCalculado)}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF2E7D32)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Observações
                TextFormField(
                  controller: _obsController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Observações / Instruções Clínicas (opcional)',
                    hintText: 'Ex: Primeira sessão, trazer toalha, pele sensível...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 24),

                // Ações
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _salvando ? null : _submeter,
                      icon: _salvando
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check, size: 18),
                      label: const Text('CONFIRMAR AGENDAMENTO', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
