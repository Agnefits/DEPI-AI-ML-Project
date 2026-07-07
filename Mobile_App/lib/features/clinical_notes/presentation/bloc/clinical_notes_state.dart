import 'package:equatable/equatable.dart';
import '../../domain/entities/clinical_note.dart';

abstract class ClinicalNotesState extends Equatable {
  const ClinicalNotesState();

  @override
  List<Object> get props => [];
}

class ClinicalNotesInitial extends ClinicalNotesState {}

class ClinicalNotesLoading extends ClinicalNotesState {}

class ClinicalNotesLoaded extends ClinicalNotesState {
  final List<ClinicalNote> notes;

  const ClinicalNotesLoaded(this.notes);

  @override
  List<Object> get props => [notes];
}

class ClinicalNotesError extends ClinicalNotesState {
  final String message;

  const ClinicalNotesError(this.message);

  @override
  List<Object> get props => [message];
}

class NoteOperationSuccess extends ClinicalNotesState {}
