import '../entities/clinical_note.dart';
import '../repositories/clinical_notes_repository.dart';

class AddNote {
  final ClinicalNotesRepository repository;

  AddNote(this.repository);

  Future<void> call(ClinicalNote note) async {
    return await repository.addNote(note);
  }
}
