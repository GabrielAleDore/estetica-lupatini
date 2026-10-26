import 'package:equatable/equatable.dart';
import '../../domain/models/cockpit_data.dart';

enum OperacoesStatus { initial, loading, loaded, error }

class OperacoesState extends Equatable {
  final OperacoesStatus status;
  final CockpitData? data;
  final String? errorMessage;
  final DateTime dataReferencia;

  const OperacoesState({
    this.status = OperacoesStatus.initial,
    this.data,
    this.errorMessage,
    required this.dataReferencia,
  });

  OperacoesState copyWith({
    OperacoesStatus? status,
    CockpitData? data,
    String? errorMessage,
    DateTime? dataReferencia,
  }) {
    return OperacoesState(
      status: status ?? this.status,
      data: data ?? this.data,
      errorMessage: errorMessage ?? this.errorMessage,
      dataReferencia: dataReferencia ?? this.dataReferencia,
    );
  }

  @override
  List<Object?> get props => [status, data, errorMessage, dataReferencia];
}
