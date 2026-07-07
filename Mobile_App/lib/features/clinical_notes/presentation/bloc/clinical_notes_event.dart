import 'package:equatable/equatable.dart';
import '../../domain/entities/clinical_note.dart';

abstract class ClinicalNotesEvent extends Equatable {
  const ClinicalNotesEvent();

  @override
  List<Object> get props => [];
}

class LoadNotes extends ClinicalNotesEvent {}

class AddNoteEvent extends ClinicalNotesEvent {
  final ClinicalNote note;

  const AddNoteEvent(this.note);

  @override
  List<Object> get props => [note];
}

class UpdateNoteEvent extends ClinicalNotesEvent {
  final ClinicalNote note;

  const UpdateNoteEvent(this.note);

  @override
  List<Object> get props => [note];
}

class DeleteNoteEvent extends ClinicalNotesEvent {
  final String id;

  const DeleteNoteEvent(this.id);

  @override
  List<Object> get props => [id];
}
