import '../entities/clinical_note.dart';
import '../repositories/clinical_notes_repository.dart';

class GetNotes {
  final ClinicalNotesRepository repository;

  GetNotes(this.repository);

  Future<List<ClinicalNote>> call() async {
    return await repository.getNotes();
  }
}
