import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class WhatsappTemplateDialog extends StatefulWidget {
  final String templateAtual;
  final ValueChanged<String> onSalvar;

  const WhatsappTemplateDialog({
    super.key,
    required this.templateAtual,
    required this.onSalvar,
  });

  @override
  State<WhatsappTemplateDialog> createState() => _WhatsappTemplateDialogState();
}

class _WhatsappTemplateDialogState extends State<WhatsappTemplateDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.templateAtual);
    _controller.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _gerarPrevia() {
    var txt = _controller.text;
    txt = txt.replaceAll('{nome_cliente}', 'Mariana Silva');
    txt = txt.replaceAll('{servico}', 'Drenagem Linfática Facial');
    txt = txt.replaceAll('{data}', '25/09/2026');
    txt = txt.replaceAll('{horario}', '15:30');
    txt = txt.replaceAll('{link_confirmacao}', 'https://estetica-lupatini.com/confirmar');
    return txt;
  }

  void _inserirTag(String tag) {
    final text = _controller.text;
    final selection = _controller.selection;
    if (selection.start >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, tag);
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + tag.length),
      );
    } else {
      _controller.text = '$text $tag';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.mark_chat_unread_outlined, color: Color(0xFF2E7D32), size: 26),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Template de Mensagem WhatsApp',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Personalize a mensagem automática enviada para as clientes',
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

              // Tags Disponíveis
              const Text(
                'Clique em uma tag dinâmica para inserir no texto:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondaryLight),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.person, size: 14),
                    label: const Text('{nome_cliente}', style: TextStyle(fontSize: 12)),
                    onPressed: () => _inserirTag('{nome_cliente}'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.spa, size: 14),
                    label: const Text('{servico}', style: TextStyle(fontSize: 12)),
                    onPressed: () => _inserirTag('{servico}'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.calendar_today, size: 14),
                    label: const Text('{data}', style: TextStyle(fontSize: 12)),
                    onPressed: () => _inserirTag('{data}'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.access_time, size: 14),
                    label: const Text('{horario}', style: TextStyle(fontSize: 12)),
                    onPressed: () => _inserirTag('{horario}'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.link, size: 14),
                    label: const Text('{link_confirmacao}', style: TextStyle(fontSize: 12)),
                    onPressed: () => _inserirTag('{link_confirmacao}'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Editor de Texto
              TextFormField(
                controller: _controller,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Texto da Mensagem',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),

              // Prévia da Mensagem no WhatsApp
              const Text(
                'Pré-visualização (como a cliente receberá no WhatsApp):',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondaryLight),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCF8C6), // Balão de conversa verde WhatsApp
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  border: Border.all(color: const Color(0xFFB9F6CA)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _gerarPrevia(),
                      style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                    ),
                    const SizedBox(height: 6),
                    const Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        '15:30  ✓✓',
                        style: TextStyle(fontSize: 10, color: Color(0xFF4CAF50), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
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
                    onPressed: () {
                      widget.onSalvar(_controller.text.trim());
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.save, size: 18),
                    label: const Text('SALVAR TEMPLATE', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
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
    );
  }
}
