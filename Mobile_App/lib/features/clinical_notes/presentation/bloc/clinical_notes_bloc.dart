import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/get_notes.dart';
import '../../domain/usecases/add_note.dart';
import '../../domain/usecases/update_note.dart';
import 'clinical_notes_event.dart';
import 'clinical_notes_state.dart';

class ClinicalNotesBloc extends Bloc<ClinicalNotesEvent, ClinicalNotesState> {
  final GetNotes getNotes;
  final AddNote addNote;
  final UpdateNote updateNote;

  ClinicalNotesBloc({
    required this.getNotes,
    required this.addNote,
    required this.updateNote,
  }) : super(ClinicalNotesInitial()) {
    on<LoadNotes>(_onLoadNotes);
    on<AddNoteEvent>(_onAddNote);
    on<UpdateNoteEvent>(_onUpdateNote);
  }

  Future<void> _onLoadNotes(LoadNotes event, Emitter<ClinicalNotesState> emit) async {
    emit(ClinicalNotesLoading());
    try {
      final notes = await getNotes();
      emit(ClinicalNotesLoaded(notes));
    } catch (e) {
      emit(ClinicalNotesError(e.toString()));
    }
  }

  Future<void> _onAddNote(AddNoteEvent event, Emitter<ClinicalNotesState> emit) async {
    emit(ClinicalNotesLoading());
    try {
      await addNote(event.note);
      emit(NoteOperationSuccess());
      add(LoadNotes());
    } catch (e) {
      emit(ClinicalNotesError(e.toString()));
    }
  }

  Future<void> _onUpdateNote(UpdateNoteEvent event, Emitter<ClinicalNotesState> emit) async {
    emit(ClinicalNotesLoading());
    try {
      await updateNote(event.note);
      emit(NoteOperationSuccess());
      add(LoadNotes());
    } catch (e) {
      emit(ClinicalNotesError(e.toString()));
    }
  }
}
