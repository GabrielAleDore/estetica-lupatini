import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/agenda_repository.dart';
import '../../domain/models/agendamento.dart';
import 'agenda_state.dart';

class AgendaCubit extends Cubit<AgendaState> {
  final AgendaRepository _repository;

  AgendaCubit({AgendaRepository? repository})
      : _repository = repository ?? AgendaRepository(),
        super(AgendaState(dataSelecionada: DateTime.now()));

  /// Inicialização e carga de dados de clientes, serviços e agendamentos
  Future<void> inicializar() async {
    emit(state.copyWith(status: AgendaStatus.loading, clearMessages: true));
    try {
      final clientes = await _repository.obterClientesParaSelecao();
      final servicos = await _repository.obterServicosParaSelecao();

      emit(state.copyWith(
        clientes: clientes,
        servicos: servicos,
      ));

      await carregarAgendamentos();
    } catch (e) {
      emit(state.copyWith(
        status: AgendaStatus.error,
        errorMessage: 'Erro ao carregar dados da agenda: $e',
      ));
    }
  }

  /// Carrega os agendamentos do período atual (dia ou semana)
  Future<void> carregarAgendamentos() async {
    emit(state.copyWith(status: AgendaStatus.loading, clearMessages: true));
    try {
      DateTime inicio;
      DateTime fim;

      if (state.modoVisao == 'SEMANA') {
        // Encontra a segunda-feira da semana da dataSelecionada
        final d = state.dataSelecionada;
        final diaSemana = d.weekday; // 1 = Monday, 7 = Sunday
        inicio = DateTime(d.year, d.month, d.day - (diaSemana - 1), 0, 0, 0);
        fim = DateTime(inicio.year, inicio.month, inicio.day + 6, 23, 59, 59);
      } else {
        // Modo DIA ou RELATÓRIOS
        final d = state.dataSelecionada;
        inicio = DateTime(d.year, d.month, d.day, 0, 0, 0);
        fim = DateTime(d.year, d.month, d.day, 23, 59, 59);
      }

      final agendamentos = await _repository.obterAgendamentos(
        dataInicio: inicio,
        dataFim: fim,
        status: state.filtroStatus == 'TODOS' ? null : state.filtroStatus,
      );

      // Carrega métricas do mês corrente da data selecionada
      final inicioMes = DateTime(state.dataSelecionada.year, state.dataSelecionada.month, 1);
      final fimMes = DateTime(state.dataSelecionada.year, state.dataSelecionada.month + 1, 0, 23, 59, 59);
      final metricas = await _repository.calcularMetricas(dataInicio: inicioMes, dataFim: fimMes);

      emit(state.copyWith(
        status: AgendaStatus.success,
        agendamentos: agendamentos,
        metricas: metricas,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AgendaStatus.error,
        errorMessage: 'Falha ao buscar agendamentos: $e',
      ));
    }
  }

  /// Altera a data foco da agenda
  void mudarData(DateTime novaData) {
    emit(state.copyWith(dataSelecionada: novaData));
    carregarAgendamentos();
  }

  /// Altera o modo de visualização ('DIA', 'SEMANA', 'RELATORIOS')
  void mudarModoVisao(String novoModo) {
    emit(state.copyWith(modoVisao: novoModo));
    carregarAgendamentos();
  }

  /// Altera o filtro de status
  void mudarFiltroStatus(String status) {
    emit(state.copyWith(filtroStatus: status));
    carregarAgendamentos();
  }

  /// Registra um novo agendamento
  Future<bool> criarAgendamento({
    required String clienteId,
    required String servicoId,
    required DateTime dataHoraInicio,
    required DateTime dataHoraFim,
    String? observacoes,
  }) async {
    emit(state.copyWith(status: AgendaStatus.loading, clearMessages: true));
    try {
      await _repository.criarAgendamento(
        clienteId: clienteId,
        servicoId: servicoId,
        dataHoraInicio: dataHoraInicio,
        dataHoraFim: dataHoraFim,
        observacoes: observacoes,
      );

      emit(state.copyWith(
        status: AgendaStatus.success,
        successMessage: 'Agendamento cadastrado com sucesso!',
      ));

      await carregarAgendamentos();
      return true;
    } catch (e) {
      emit(state.copyWith(
        status: AgendaStatus.error,
        errorMessage: 'Erro ao criar agendamento: $e',
      ));
      return false;
    }
  }

  /// Altera o status do agendamento ('AGENDADO', 'CONFIRMADO', 'CANCELADO', 'CONCLUIDO')
  Future<void> atualizarStatus(String id, String novoStatus) async {
    try {
      await _repository.atualizarStatus(id, novoStatus);

      final listaAtualizada = state.agendamentos.map((a) {
        if (a.id == id) {
          return a.copyWith(status: novoStatus);
        }
        return a;
      }).toList();

      emit(state.copyWith(
        agendamentos: listaAtualizada,
        successMessage: 'Status alterado para "$novoStatus".',
      ));

      // Atualiza as métricas
      final inicioMes = DateTime(state.dataSelecionada.year, state.dataSelecionada.month, 1);
      final fimMes = DateTime(state.dataSelecionada.year, state.dataSelecionada.month + 1, 0, 23, 59, 59);
      final metricas = await _repository.calcularMetricas(dataInicio: inicioMes, dataFim: fimMes);
      emit(state.copyWith(metricas: metricas));
    } catch (e) {
      emit(state.copyWith(
        status: AgendaStatus.error,
        errorMessage: 'Erro ao atualizar status: $e',
      ));
    }
  }

  /// Exclui um agendamento
  Future<void> excluirAgendamento(String id) async {
    try {
      await _repository.excluirAgendamento(id);
      final listaAtualizada = state.agendamentos.where((a) => a.id != id).toList();
      emit(state.copyWith(
        agendamentos: listaAtualizada,
        successMessage: 'Agendamento excluído com sucesso.',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AgendaStatus.error,
        errorMessage: 'Erro ao excluir agendamento: $e',
      ));
    }
  }

  /// Salva novo template de mensagens do WhatsApp
  void salvarWhatsappTemplate(String novoTemplate) {
    emit(state.copyWith(
      whatsappTemplate: novoTemplate,
      successMessage: 'Template do WhatsApp atualizado com sucesso!',
    ));
  }

  /// Formata a mensagem com as tags dinâmicas
  String formatarMensagemWhatsapp(Agendamento agendamento) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');

    var texto = state.whatsappTemplate;
    texto = texto.replaceAll('{nome_cliente}', agendamento.clienteNome);
    texto = texto.replaceAll('{servico}', agendamento.servicoNome);
    texto = texto.replaceAll('{data}', dateFormat.format(agendamento.dataHoraInicio));
    texto = texto.replaceAll('{horario}', timeFormat.format(agendamento.dataHoraInicio));
    texto = texto.replaceAll('{link_confirmacao}', 'https://estetica-lupatini.com/confirmar');

    return texto;
  }

  /// Envia lembrete de WhatsApp abrindo a conversa via wa.me
  Future<bool> enviarWhatsapp(Agendamento agendamento) async {
    try {
      var telefoneLimpo = agendamento.clienteTelefone.replaceAll(RegExp(r'\D'), '');

      if (telefoneLimpo.isEmpty) {
        emit(state.copyWith(
          status: AgendaStatus.error,
          errorMessage: 'Esta cliente não possui telefone/WhatsApp cadastrado.',
        ));
        return false;
      }

      if (telefoneLimpo.length == 10 || telefoneLimpo.length == 11) {
        telefoneLimpo = '55$telefoneLimpo';
      }

      final mensagem = formatarMensagemWhatsapp(agendamento);
      final uri = Uri.parse('https://wa.me/$telefoneLimpo?text=${Uri.encodeComponent(mensagem)}');

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }

      await _repository.marcarLembreteEnviado(agendamento.id);

      final listaAtualizada = state.agendamentos.map((a) {
        if (a.id == agendamento.id) {
          return a.copyWith(lembreteEnviado: true);
        }
        return a;
      }).toList();

      emit(state.copyWith(
        agendamentos: listaAtualizada,
        successMessage: 'Lembrete enviado via WhatsApp para ${agendamento.clienteNome}!',
      ));

      return true;
    } catch (e) {
      emit(state.copyWith(
        status: AgendaStatus.error,
        errorMessage: 'Não foi possível abrir o WhatsApp: $e',
      ));
      return false;
    }
  }
}
