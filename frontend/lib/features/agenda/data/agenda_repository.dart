import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../domain/models/agendamento.dart';

class AgendaRepository {
  final SupabaseClient _supabase;

  AgendaRepository({SupabaseClient? client})
      : _supabase = client ?? SupabaseService.client;

  /// Retorna lista de agendamentos dentro de um intervalo de datas
  Future<List<Agendamento>> obterAgendamentos({
    DateTime? dataInicio,
    DateTime? dataFim,
    String? status,
  }) async {
    var query = _supabase
        .from('agendamentos')
        .select('*, clientes(id, nome, telefone), servicos(id, nome, preco, duracao_minutos)');

    if (dataInicio != null) {
      query = query.gte('data_hora_inicio', dataInicio.toUtc().toIso8601String());
    }
    if (dataFim != null) {
      query = query.lte('data_hora_inicio', dataFim.toUtc().toIso8601String());
    }
    if (status != null && status.isNotEmpty && status != 'TODOS') {
      query = query.eq('status', status);
    }

    final response = await query.order('data_hora_inicio', ascending: true);
    final list = response as List<dynamic>;
    return list.map((item) => Agendamento.fromJson(item as Map<String, dynamic>)).toList();
  }

  /// Insere um novo agendamento
  Future<Agendamento> criarAgendamento({
    required String clienteId,
    required String servicoId,
    required DateTime dataHoraInicio,
    required DateTime dataHoraFim,
    String? observacoes,
  }) async {
    final insertData = {
      'cliente_id': clienteId,
      'servico_id': servicoId,
      'data_hora_inicio': dataHoraInicio.toUtc().toIso8601String(),
      'data_hora_fim': dataHoraFim.toUtc().toIso8601String(),
      'status': 'AGENDADO',
      'observacoes': observacoes,
      'lembrete_enviado': false,
    };

    final res = await _supabase
        .from('agendamentos')
        .insert(insertData)
        .select('*, clientes(id, nome, telefone), servicos(id, nome, preco, duracao_minutos)')
        .single();

    return Agendamento.fromJson(res);
  }

  /// Altera o status do agendamento ('AGENDADO', 'CONFIRMADO', 'CANCELADO', 'CONCLUIDO')
  Future<void> atualizarStatus(String id, String novoStatus) async {
    await _supabase.from('agendamentos').update({
      'status': novoStatus,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  /// Registra que o lembrete de WhatsApp foi enviado
  Future<void> marcarLembreteEnviado(String id) async {
    await _supabase.from('agendamentos').update({
      'lembrete_enviado': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  /// Exclui um agendamento
  Future<void> excluirAgendamento(String id) async {
    await _supabase.from('agendamentos').delete().eq('id', id);
  }

  /// Carrega clientes cadastrados para o formulário
  Future<List<Map<String, dynamic>>> obterClientesParaSelecao() async {
    final res = await _supabase
        .from('clientes')
        .select('id, nome, telefone, is_fidelizada, desconto_fidelidade_padrao')
        .order('nome', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  /// Carrega serviços cadastrados com tempo de duração para preenchimento automático
  Future<List<Map<String, dynamic>>> obterServicosParaSelecao() async {
    final res = await _supabase
        .from('servicos')
        .select('id, nome, preco, duracao_minutos, codigo_sequencial, preco_promocional, em_promocao')
        .eq('ativo', true)
        .order('codigo_sequencial', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  /// Calcula estatísticas e métricas de comparecimento para relatórios
  Future<Map<String, dynamic>> calcularMetricas({
    required DateTime dataInicio,
    required DateTime dataFim,
  }) async {
    final response = await _supabase
        .from('agendamentos')
        .select('id, status, data_hora_fim')
        .gte('data_hora_inicio', dataInicio.toUtc().toIso8601String())
        .lte('data_hora_inicio', dataFim.toUtc().toIso8601String());

    final list = response as List<dynamic>;
    final total = list.length;
    int agendados = 0;
    int confirmados = 0;
    int concluidos = 0;
    int cancelados = 0;
    int noShows = 0;

    final agora = DateTime.now();

    for (final item in list) {
      final status = item['status'] as String? ?? 'AGENDADO';
      final fim = DateTime.tryParse(item['data_hora_fim']?.toString() ?? '');

      if (status == 'CONCLUIDO') {
        concluidos++;
      } else if (status == 'CONFIRMADO') {
        confirmados++;
      } else if (status == 'CANCELADO') {
        cancelados++;
      } else if (status == 'AGENDADO') {
        if (fim != null && fim.isBefore(agora)) {
          noShows++;
        } else {
          agendados++;
        }
      }
    }

    final totalFinalizados = concluidos + cancelados + noShows;
    final taxaComparecimento = totalFinalizados > 0
        ? (concluidos / totalFinalizados) * 100
        : 0.0;
    final taxaConfirmacao = total > 0
        ? ((confirmados + concluidos) / total) * 100
        : 0.0;

    return {
      'total': total,
      'agendados': agendados,
      'confirmados': confirmados,
      'concluidos': concluidos,
      'cancelados': cancelados,
      'no_shows': noShows,
      'taxa_comparecimento': taxaComparecimento,
      'taxa_confirmacao': taxaConfirmacao,
    };
  }
}
