import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/get_patients.dart';
import '../../domain/usecases/add_patient.dart';
import '../../domain/usecases/update_patient.dart';
import 'patient_event.dart';
import 'patient_state.dart';

class PatientBloc extends Bloc<PatientEvent, PatientState> {
  final GetPatients getPatients;
  final AddPatient addPatient;
  final UpdatePatient updatePatient;

  PatientBloc({
    required this.getPatients,
    required this.addPatient,
    required this.updatePatient,
  }) : super(PatientInitial()) {
    on<LoadPatientsEvent>((event, emit) async {
      emit(PatientLoading());
      try {
        final patients = await getPatients();
        emit(PatientLoaded(patients));
      } catch (e) {
        emit(PatientError(e.toString()));
      }
    });

    on<AddPatientEvent>((event, emit) async {
      emit(PatientLoading());
      try {
        await addPatient(event.patient);
        final patients = await getPatients();
        emit(PatientLoaded(patients));
      } catch (e) {
        emit(PatientError(e.toString()));
      }
    });

    on<UpdatePatientEvent>((event, emit) async {
      emit(PatientLoading());
      try {
        await updatePatient(event.patient);
        final patients = await getPatients();
        emit(PatientLoaded(patients));
      } catch (e) {
        emit(PatientError(e.toString()));
      }
    });
  }
}
