import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/models/cockpit_data.dart';

class AniversariantesSemanaCard extends StatelessWidget {
  final List<AniversarianteItem> aniversariantes;

  const AniversariantesSemanaCard({
    super.key,
    required this.aniversariantes,
  });

  Future<void> _abrirWhatsApp(BuildContext context, AniversarianteItem item) async {
    final digitosTelefone = item.telefone.replaceAll(RegExp(r'\D'), '');
    if (digitosTelefone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este cliente não possui telefone cadastrado.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final telefoneFormatado = digitosTelefone.startsWith('55')
        ? digitosTelefone
        : '55$digitosTelefone';

    final primeiroNome = item.nome.trim().split(' ').first;
    final mensagem = Uri.encodeComponent(
      'Olá $primeiroNome! 🎂✨ A equipe da Estética Lupatini passa para lhe desejar um felicíssimo aniversário! Que este novo ciclo traga muita saúde, momentos especiais e bem-estar. Preparamos um carinho especial para o seu mês de aniversário!',
    );

    final url = Uri.parse('https://wa.me/$telefoneFormatado?text=$mensagem');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir o WhatsApp.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCE4EC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.cake_outlined, color: Color(0xFFC2185B), size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aniversariantes da Semana',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Envie os parabéns e encante seus clientes',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (aniversariantes.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              alignment: Alignment.center,
              child: const Text(
                'Nenhum aniversariante cadastrado para esta semana.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondaryLight,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: aniversariantes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = aniversariantes[index];

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: item.isHoje ? const Color(0xFFFFF8E1) : AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: item.isHoje ? const Color(0xFFFFB300) : AppColors.borderLight,
                      width: item.isHoje ? 1.2 : 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: item.isHoje ? const Color(0xFFFFB300) : AppColors.primarySubtle,
                        child: Text(
                          item.nome.isNotEmpty ? item.nome[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: item.isHoje ? Colors.white : AppColors.primaryDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.nome,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (item.isHoje)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    margin: const EdgeInsets.only(left: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD84315),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'HOJE! 🎉',
                                      style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Dia ${item.diaMesFormatado}${item.idadeACompletar != null ? " • Completa ${item.idadeACompletar} anos" : ""}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF2E7D32), size: 18),
                        tooltip: 'Enviar Parabéns no WhatsApp',
                        onPressed: () => _abrirWhatsApp(context, item),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
