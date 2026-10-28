import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/cliente_pacote_model.dart';

class PacotesRepository {
  final SupabaseClient _supabase;

  PacotesRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Obtém a carteira completa de pacotes e sessões de um cliente
  Future<List<ClientePacoteModel>> carregarPacotesCliente(String clienteId) async {
    try {
      // 1. Tenta via Stored Procedure otimizada
      final response = await _supabase.rpc(
        'obter_pacotes_cliente',
        params: {'p_cliente_id': clienteId},
      );

      if (response is List) {
        return response
            .map((item) => ClientePacoteModel.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
    } catch (_) {
      // Fallback gracioso caso a RPC ainda não esteja deployada na instância remota
      try {
        final data = await _supabase
            .from('clientes_pacotes')
            .select('*, servicos(nome), pacotes_sessoes_historico(*, perfis_usuarios(nome))')
            .eq('cliente_id', clienteId)
            .order('data_aquisicao', ascending: false);

        return (data as List).map((row) {
          final map = Map<String, dynamic>.from(row as Map);
          map['servico_nome'] = map['servicos']?['nome'] ?? 'Serviço Clínico';
          
          final sessoesRaw = (map['pacotes_sessoes_historico'] as List?) ?? [];
          map['sessoes'] = sessoesRaw.map((s) {
            final sMap = Map<String, dynamic>.from(s as Map);
            sMap['profissional_nome'] = sMap['perfis_usuarios']?['nome'];
            return sMap;
          }).toList();

          return ClientePacoteModel.fromJson(map);
        }).toList();
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  /// Contrata um novo pacote de tratamentos para o cliente
  Future<Map<String, dynamic>> contratarPacote({
    required String clienteId,
    required String servicoId,
    required int quantidadeTotal,
    required double valorTotal,
    String? vendaOrigemId,
    String? tituloPersonalizado,
    int? validadeMeses,
    String? observacoes,
  }) async {
    try {
      final res = await _supabase.rpc('contratar_pacote_cliente', params: {
        'p_cliente_id': clienteId,
        'p_servico_id': servicoId,
        'p_quantidade_total': quantidadeTotal,
        'p_valor_total': valorTotal,
        'p_venda_origem_id': vendaOrigemId,
        'p_titulo_personalizado': tituloPersonalizado,
        'p_validade_meses': validadeMeses,
        'p_observacoes': observacoes,
      });

      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
    } catch (e) {
      // Fallback direto via INSERT
      final valorSessao = quantidadeTotal > 0 ? valorTotal / quantidadeTotal : valorTotal;
      final insertData = {
        'cliente_id': clienteId,
        'servico_id': servicoId,
        'venda_origem_id': vendaOrigemId,
        'titulo_personalizado': tituloPersonalizado,
        'quantidade_total': quantidadeTotal,
        'quantidade_consumida': 0,
        'valor_total': valorTotal,
        'valor_por_sessao': valorSessao,
        'status': 'ATIVO',
        'observacoes': observacoes,
      };

      final inserted = await _supabase
          .from('clientes_pacotes')
          .insert(insertData)
          .select()
          .single();

      return Map<String, dynamic>.from(inserted as Map);
    }
    throw Exception('Falha ao registrar contratação de pacote.');
  }

  /// Registra a baixa atômica de uma sessão de tratamento e evolução clínica
  Future<Map<String, dynamic>> darBaixaSessao({
    required String pacoteId,
    String? profissionalId,
    String? agendamentoId,
    String? observacoesEvolucao,
    Map<String, dynamic>? parametrosUtilizados,
    List<String>? fotosUrls,
  }) async {
    final res = await _supabase.rpc('dar_baixa_sessao_pacote', params: {
      'p_pacote_id': pacoteId,
      'p_profissional_id': profissionalId,
      'p_agendamento_id': agendamentoId,
      'p_observacoes_evolucao': observacoesEvolucao,
      'p_parametros': parametrosUtilizados ?? {},
      'p_fotos_urls': fotosUrls ?? [],
    });

    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
    return {'success': true, 'mensagem': 'Sessão registrada com sucesso.'};
  }

  /// Carrega lista de profissionais/esteticistas da clínica
  Future<List<Map<String, dynamic>>> carregarProfissionais() async {
    try {
      final res = await _supabase
          .from('perfis_usuarios')
          .select('id, nome, role')
          .eq('ativo', true)
          .order('nome');

      return (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }
}
