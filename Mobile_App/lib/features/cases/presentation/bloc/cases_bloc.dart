import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/get_cases.dart';
import '../../domain/usecases/create_case.dart';
import '../../domain/usecases/update_case.dart';
import 'cases_event.dart';
import 'cases_state.dart';

class CasesBloc extends Bloc<CasesEvent, CasesState> {
  final GetCasesUseCase getCasesUseCase;
  final CreateCaseUseCase createCaseUseCase;
  final UpdateCaseUseCase updateCaseUseCase;

  CasesBloc({
    required this.getCasesUseCase,
    required this.createCaseUseCase,
    required this.updateCaseUseCase,
  }) : super(CasesInitial()) {
    on<LoadCasesEvent>(_onLoadCases);
    on<CreateCaseEvent>(_onCreateCase);
    on<UpdateCaseEvent>(_onUpdateCase);
  }

  Future<void> _onLoadCases(LoadCasesEvent event, Emitter<CasesState> emit) async {
    emit(CasesLoading());
    try {
      final cases = await getCasesUseCase();
      emit(CasesLoaded(cases));
    } catch (e) {
      emit(CasesError(e.toString()));
    }
  }

  Future<void> _onCreateCase(CreateCaseEvent event, Emitter<CasesState> emit) async {
    emit(CasesLoading());
    try {
      await createCaseUseCase(event.newCase);
      emit(const CaseOperationSuccess("Case created successfully"));
      add(LoadCasesEvent());
    } catch (e) {
      emit(CasesError(e.toString()));
      add(LoadCasesEvent());
    }
  }

  Future<void> _onUpdateCase(UpdateCaseEvent event, Emitter<CasesState> emit) async {
    emit(CasesLoading());
    try {
      await updateCaseUseCase(event.updatedCase);
      emit(const CaseOperationSuccess("Case updated successfully"));
      add(LoadCasesEvent());
    } catch (e) {
      emit(CasesError(e.toString()));
      add(LoadCasesEvent());
    }
  }
}
