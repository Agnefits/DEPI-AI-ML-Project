import '../entities/clinical_note.dart';
import '../repositories/clinical_notes_repository.dart';

class UpdateNote {
  final ClinicalNotesRepository repository;

  UpdateNote(this.repository);

  Future<void> call(ClinicalNote note) async {
    return await repository.updateNote(note);
  }
}
