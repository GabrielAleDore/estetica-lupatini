import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';

class ClientesRepository {
  final SupabaseClient _supabase;

  ClientesRepository({SupabaseClient? client})
      : _supabase = client ?? SupabaseService.client;

  Future<List<Map<String, dynamic>>> listarClientes({String? busca}) async {
    try {
      var query = _supabase.from('clientes').select('*').eq('status', 'ATIVO');

      if (busca != null && busca.trim().isNotEmpty) {
        final termo = '%${busca.trim()}%';
        query = query.or('nome.ilike.$termo,cpf.ilike.$termo,telefone.ilike.$termo');
      }

      final response = await query.order('nome').limit(100);
      final List<Map<String, dynamic>> clientes = List<Map<String, dynamic>>.from(response);

      try {
        final vendasRes = await _supabase
            .from('vendas')
            .select('cliente_id, valor_liquido')
            .eq('status', 'CONCLUIDA');

        final Map<String, double> totaisGastos = {};
        final Map<String, int> contagemVendas = {};

        for (final v in vendasRes) {
          final cid = v['cliente_id'] as String?;
          if (cid != null) {
            final val = (v['valor_liquido'] as num?)?.toDouble() ?? 0.0;
            totaisGastos[cid] = (totaisGastos[cid] ?? 0.0) + val;
            contagemVendas[cid] = (contagemVendas[cid] ?? 0) + 1;
          }
        }

        for (var i = 0; i < clientes.length; i++) {
          final cid = clientes[i]['id'] as String;
          clientes[i] = {
            ...clientes[i],
            'total_gasto': totaisGastos[cid] ?? 0.0,
            'total_compras': contagemVendas[cid] ?? 0,
          };
        }
      } catch (_) {
        // Prossegue mesmo se a agregação de vendas sofrer timeout
      }

      return clientes;
    } catch (e) {
      throw Exception('Erro ao listar pacientes do Supabase: $e');
    }
  }

  Map<String, dynamic> _normalizarPayload(Map<String, dynamic> dados) {
    final payload = Map<String, dynamic>.from(dados);
    if (payload['cpf'] != null) {
      final cleanCpf = (payload['cpf'] as String).replaceAll(RegExp(r'\D'), '');
      payload['cpf'] = cleanCpf.isNotEmpty ? cleanCpf : null;
    }
    if (payload['telefone'] != null) {
      final cleanTel = (payload['telefone'] as String).replaceAll(RegExp(r'\D'), '');
      payload['telefone'] = cleanTel.isNotEmpty ? cleanTel : null;
    }
    if (payload['email'] != null && (payload['email'] as String).trim().isEmpty) {
      payload['email'] = null;
    }
    if (payload['data_nascimento'] != null) {
      final dataStr = (payload['data_nascimento'] as String).trim();
      if (dataStr.isEmpty) {
        payload['data_nascimento'] = null;
      } else if (dataStr.contains('/')) {
        final parts = dataStr.split('/');
        if (parts.length == 3) {
          payload['data_nascimento'] =
              '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
        }
      }
    }
    if (payload['anamnese'] == null) {
      payload['anamnese'] = <String, dynamic>{
        'tipo_pele': null,
        'alergias': [],
        'medicamentos_uso': [],
        'historico_cirurgico': null,
        'queixa_principal': null,
        'observacoes_tecnicas': null,
      };
    }
    return payload;
  }

  Future<Map<String, dynamic>> cadastrarCliente(Map<String, dynamic> dados) async {
    try {
      final payload = _normalizarPayload(dados);

      // Verificação prévia de duplicidade de CPF se fornecido
      if (payload['cpf'] != null) {
        final existente = await _supabase
            .from('clientes')
            .select('id, nome')
            .eq('cpf', payload['cpf'])
            .maybeSingle();

        if (existente != null) {
          throw Exception('Já existe um paciente cadastrado com este CPF (${existente['nome']}).');
        }
      }

      final response = await _supabase.from('clientes').insert(payload).select().single();
      return Map<String, dynamic>.from(response);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw Exception('Já existe um paciente cadastrado com este CPF.');
      }
      throw Exception('Erro no banco de dados Supabase: ${e.message}');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<Map<String, dynamic>> atualizarCliente(String id, Map<String, dynamic> dados) async {
    try {
      final payload = _normalizarPayload(dados);
      final response = await _supabase.from('clientes').update(payload).eq('id', id).select().single();
      return Map<String, dynamic>.from(response);
    } catch (e) {
      throw Exception('Erro ao atualizar paciente no Supabase: $e');
    }
  }

  Future<void> atualizarFidelidade(String id, bool isFidelizada, double desconto) async {
    try {
      await _supabase.from('clientes').update({
        'is_fidelizada': isFidelizada,
        'desconto_fidelidade_padrao': desconto,
      }).eq('id', id);
    } catch (e) {
      throw Exception('Erro ao atualizar status VIP de fidelidade: $e');
    }
  }

  Future<void> excluirCliente(String id) async {
    try {
      await _supabase.from('clientes').update({'status': 'INATIVO'}).eq('id', id);
    } catch (e) {
      throw Exception('Erro ao inativar paciente no Supabase: $e');
    }
  }
}
