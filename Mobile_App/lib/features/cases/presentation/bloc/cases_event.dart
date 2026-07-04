import 'package:equatable/equatable.dart';
import '../../domain/entities/case_entity.dart';

abstract class CasesEvent extends Equatable {
  const CasesEvent();

  @override
  List<Object> get props => [];
}

class LoadCasesEvent extends CasesEvent {}

class CreateCaseEvent extends CasesEvent {
  final CaseEntity newCase;
  const CreateCaseEvent(this.newCase);
  
  @override
  List<Object> get props => [newCase];
}

class UpdateCaseEvent extends CasesEvent {
  final CaseEntity updatedCase;
  const UpdateCaseEvent(this.updatedCase);
  
  @override
  List<Object> get props => [updatedCase];
}
