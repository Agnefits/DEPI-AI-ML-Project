import '../../domain/entities/clinical_note.dart';
import '../../domain/repositories/clinical_notes_repository.dart';
import '../datasources/clinical_notes_remote_data_source.dart';

class ClinicalNotesRepositoryImpl implements ClinicalNotesRepository {
  final ClinicalNotesRemoteDataSource remoteDataSource;

  ClinicalNotesRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<ClinicalNote>> getNotes() async {
    return await remoteDataSource.getNotes();
  }

  @override
  Future<void> addNote(ClinicalNote note) async {
    // TODO: implement when API is available
  }

  @override
  Future<void> updateNote(ClinicalNote note) async {
    // TODO: implement when API is available
  }

  @override
  Future<void> deleteNote(String id) async {
    // TODO: implement when API is available
  }
}
