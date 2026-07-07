import '../entities/clinical_note.dart';

abstract class ClinicalNotesRepository {
  Future<List<ClinicalNote>> getNotes();
  Future<void> addNote(ClinicalNote note);
  Future<void> updateNote(ClinicalNote note);
  Future<void> deleteNote(String id);
}
