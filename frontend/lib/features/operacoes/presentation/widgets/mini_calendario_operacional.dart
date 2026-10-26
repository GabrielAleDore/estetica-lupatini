import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/models/cockpit_data.dart';

class MiniCalendarioOperacional extends StatelessWidget {
  final DateTime dataSelecionada;
  final Map<DateTime, int> diasComAgendamento;
  final List<AgendamentoMiniItem> agendamentosDoDia;
  final ValueChanged<DateTime> onDiaSelecionado;
  final VoidCallback onAbrirAgendaCompleta;

  const MiniCalendarioOperacional({
    super.key,
    required this.dataSelecionada,
    required this.diasComAgendamento,
    required this.agendamentosDoDia,
    required this.onDiaSelecionado,
    required this.onAbrirAgendaCompleta,
  });

  @override
  Widget build(BuildContext context) {
    final mesFormat = DateFormat('MMMM yyyy', 'pt_BR');
    final mesAnoTexto = mesFormat.format(dataSelecionada);
    final mesAnoCapitalizado = mesAnoTexto[0].toUpperCase() + mesAnoTexto.substring(1);

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
          // Cabeçalho do Calendário
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.event_available, color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    mesAnoCapitalizado,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      final novoMes = DateTime(dataSelecionada.year, dataSelecionada.month - 1, 1);
                      onDiaSelecionado(novoMes);
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      final novoMes = DateTime(dataSelecionada.year, dataSelecionada.month + 1, 1);
                      onDiaSelecionado(novoMes);
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Cabeçalho dos Dias da Semana (D, S, T, Q, Q, S, S)
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _DiaSemanaHeader('D'),
              _DiaSemanaHeader('S'),
              _DiaSemanaHeader('T'),
              _DiaSemanaHeader('Q'),
              _DiaSemanaHeader('Q'),
              _DiaSemanaHeader('S'),
              _DiaSemanaHeader('S'),
            ],
          ),
          const SizedBox(height: 6),

          // Grade de Dias do Mês
          _buildGradeDias(),
          const Divider(height: 24),

          // Lista de Agendamentos do Dia Selecionado
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Agendamentos (${DateFormat('dd/MM').format(dataSelecionada)}):',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight),
              ),
              TextButton(
                onPressed: onAbrirAgendaCompleta,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Ver Agenda', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (agendamentosDoDia.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              child: const Text(
                'Nenhum agendamento para este dia.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight, fontStyle: FontStyle.italic),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: agendamentosDoDia.length > 4 ? 4 : agendamentosDoDia.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final item = agendamentosDoDia[index];
                final hora = DateFormat('HH:mm').format(item.dataHoraInicio);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          hora,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.clienteNome,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              item.servicoNome,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10, color: AppColors.textSecondaryLight),
                            ),
                          ],
                        ),
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

  Widget _buildGradeDias() {
    final primeiroDiaMes = DateTime(dataSelecionada.year, dataSelecionada.month, 1);
    final ultimoDiaMes = DateTime(dataSelecionada.year, dataSelecionada.month + 1, 0);
    final primeiroDiaSemana = (primeiroDiaMes.weekday % 7); // Domingo = 0

    final List<Widget> diasWidgets = [];

    // Espaços vazios antes do 1º dia
    for (int i = 0; i < primeiroDiaSemana; i++) {
      diasWidgets.add(const SizedBox(width: 28, height: 28));
    }

    final hoje = DateTime.now();

    for (int dia = 1; dia <= ultimoDiaMes.day; dia++) {
      final dataAtual = DateTime(dataSelecionada.year, dataSelecionada.month, dia);
      final isSelecionado = dataSelecionada.year == dataAtual.year &&
          dataSelecionada.month == dataAtual.month &&
          dataSelecionada.day == dataAtual.day;

      final isHoje = hoje.year == dataAtual.year &&
          hoje.month == dataAtual.month &&
          hoje.day == dataAtual.day;

      // Verifica se possui agendamentos nesse dia
      final chaveData = DateTime(dataAtual.year, dataAtual.month, dataAtual.day);
      final qtdAgendamentos = diasComAgendamento[chaveData] ?? 0;
      final temAgendamento = qtdAgendamentos > 0;

      diasWidgets.add(
        InkWell(
          onTap: () => onDiaSelecionado(dataAtual),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 28,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelecionado
                  ? AppColors.primary
                  : (isHoje ? AppColors.primarySubtle : Colors.transparent),
              borderRadius: BorderRadius.circular(6),
              border: isHoje && !isSelecionado
                  ? Border.all(color: AppColors.primary, width: 1)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$dia',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: (isSelecionado || isHoje) ? FontWeight.bold : FontWeight.normal,
                    color: isSelecionado
                        ? Colors.white
                        : (isHoje ? AppColors.primaryDark : AppColors.textPrimaryLight),
                  ),
                ),
                if (temAgendamento)
                  Container(
                    margin: const EdgeInsets.only(top: 1),
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isSelecionado ? Colors.white : AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      alignment: WrapAlignment.start,
      children: diasWidgets,
    );
  }
}

class _DiaSemanaHeader extends StatelessWidget {
  final String label;
  const _DiaSemanaHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondaryLight,
        ),
      ),
    );
  }
}
