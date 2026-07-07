import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/dio_client.dart';

// Auth Imports
import '../features/auth/data/datasources/auth_remote_data_source.dart';
import '../features/auth/data/datasources/auth_local_data_source.dart';
import '../features/auth/data/repositories/auth_repository_impl.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/domain/usecases/login_usecase.dart';
import '../features/auth/domain/usecases/register_usecase.dart';
import '../features/auth/domain/usecases/forgot_password_usecase.dart';
import '../features/auth/domain/usecases/reset_password_usecase.dart';
import '../features/auth/domain/usecases/verify_otp_usecase.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';

// Dashboard Imports
import '../features/dashboard/domain/repositories/dashboard_repository.dart';
import '../features/dashboard/data/repositories/dashboard_repository_impl.dart';
import '../features/dashboard/domain/usecases/get_dashboard_data_usecase.dart';
import '../features/dashboard/domain/usecases/get_analytics_data_usecase.dart';
import '../features/dashboard/domain/usecases/refresh_dashboard_usecase.dart';
import '../features/dashboard/presentation/bloc/dashboard_bloc.dart';

// Notification Imports
import '../features/notifications/data/datasources/notification_remote_data_source.dart';
import '../features/notifications/data/repositories/notification_repository_impl.dart';
import '../features/notifications/domain/repositories/notification_repository.dart';
import '../features/notifications/domain/usecases/get_notifications.dart';
import '../features/notifications/domain/usecases/mark_as_read.dart';
import '../features/notifications/domain/usecases/delete_notification.dart';
import '../features/notifications/presentation/bloc/notification_bloc.dart';

// Profile Imports
import '../features/profile/data/datasources/profile_remote_data_source.dart';
import '../features/profile/domain/repositories/profile_repository.dart';
import '../features/profile/data/repositories/profile_repository_impl.dart';
import '../features/profile/domain/usecases/get_user_profile_usecase.dart';
import '../features/profile/domain/usecases/update_user_profile_usecase.dart';
import '../features/profile/domain/usecases/change_password_usecase.dart';
import '../features/profile/domain/usecases/upload_avatar_usecase.dart';
import '../features/profile/presentation/bloc/profile_bloc.dart';

// Clinical Notes Imports
import '../features/clinical_notes/data/datasources/clinical_notes_remote_data_source.dart';
import '../features/clinical_notes/data/repositories/clinical_notes_repository_impl.dart';
import '../features/clinical_notes/domain/repositories/clinical_notes_repository.dart';
import '../features/clinical_notes/domain/usecases/get_notes.dart';
import '../features/clinical_notes/domain/usecases/add_note.dart';
import '../features/clinical_notes/domain/usecases/update_note.dart';
import '../features/clinical_notes/presentation/bloc/clinical_notes_bloc.dart';

// Cases Imports
import '../features/cases/data/datasources/cases_remote_data_source.dart';
import '../features/cases/data/repositories/case_repository_impl.dart';
import '../features/cases/domain/repositories/case_repository.dart';
import '../features/cases/domain/usecases/get_cases.dart';
import '../features/cases/domain/usecases/get_case_details.dart';
import '../features/cases/domain/usecases/create_case.dart';
import '../features/cases/domain/usecases/update_case.dart';
import '../features/cases/domain/usecases/delete_case.dart';
import '../features/cases/presentation/bloc/cases_bloc.dart';

// AI Imports
import '../features/ai/data/datasources/ai_remote_data_source.dart';

// Reports Imports
import '../features/reports/data/datasources/reports_remote_data_source.dart';

// Patients Imports
import '../features/patients/data/datasources/patients_remote_data_source.dart';
import '../features/patients/data/repositories/patient_repository_impl.dart';
import '../features/patients/domain/repositories/patient_repository.dart';
import '../features/patients/domain/usecases/get_patients.dart';
import '../features/patients/domain/usecases/get_patient_by_id.dart';
import '../features/patients/domain/usecases/add_patient.dart';
import '../features/patients/domain/usecases/update_patient.dart';
import '../features/patients/domain/usecases/delete_patient.dart';
import '../features/patients/presentation/bloc/patient_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Core
  sl.registerLazySingleton<DioClient>(() => DioClient(
        tokenProvider: () async {
          final auth = await sl<AuthLocalDataSource>().loadAuth();
          return auth?.token;
        },
      ));

  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);

  // ==========================================
  // Auth Feature
  // ==========================================

  // Data sources
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(client: sl()),
  );
  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSource(prefs: sl()),
  );

  // Repositories
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: sl()),
  );

  // Use cases
  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => RegisterUseCase(sl()));
  sl.registerLazySingleton(() => ForgotPasswordUseCase(sl()));
  sl.registerLazySingleton(() => ResetPasswordUseCase(sl()));
  sl.registerLazySingleton(() => VerifyOtpUseCase(sl()));

  // Bloc
  sl.registerFactory(
    () => AuthBloc(
      loginUseCase: sl(),
      registerUseCase: sl(),
      forgotPasswordUseCase: sl(),
      verifyOtpUseCase: sl(),
      resetPasswordUseCase: sl(),
      localDataSource: sl(),
    ),
  );

  // ==========================================
  // Dashboard Feature
  // ==========================================

  // Repository
  sl.registerLazySingleton<DashboardRepository>(
    () => DashboardRepositoryImpl(client: sl()),
  );

  // Use cases
  sl.registerLazySingleton(() => GetDashboardDataUseCase(sl()));
  sl.registerLazySingleton(() => GetAnalyticsDataUseCase(sl()));
  sl.registerLazySingleton(() => RefreshDashboardUseCase(sl()));

  // Bloc
  sl.registerFactory(
    () => DashboardBloc(
      getDashboardDataUseCase: sl(),
      getAnalyticsDataUseCase: sl(),
      refreshDashboardUseCase: sl(),
    ),
  );

  // ==========================================
  // Notifications Feature
  // ==========================================

  // Data source
  sl.registerLazySingleton<NotificationRemoteDataSource>(
    () => NotificationRemoteDataSourceImpl(
      client: sl(),
    ),
  );

  // Repository
  sl.registerLazySingleton<NotificationRepository>(
    () => NotificationRepositoryImpl(sl()),
  );

  // Use cases
  sl.registerLazySingleton(() => GetNotificationsUseCase(sl()));
  sl.registerLazySingleton(() => MarkAsReadUseCase(sl()));
  sl.registerLazySingleton(() => DeleteNotificationUseCase(sl()));

  // Bloc
  sl.registerFactory(
    () => NotificationBloc(
      getNotificationsUseCase: sl(),
      markAsReadUseCase: sl(),
      deleteNotificationUseCase: sl(),
    ),
  );

  // ==========================================
  // Profile Feature
  // ==========================================

  // Data source
  sl.registerLazySingleton<ProfileRemoteDataSource>(
    () => ProfileRemoteDataSourceImpl(
      client: sl(),
    ),
  );

  // Repository
  sl.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(remoteDataSource: sl()),
  );

  // Use cases
  sl.registerLazySingleton(() => GetUserProfileUseCase(sl()));
  sl.registerLazySingleton(() => UpdateUserProfileUseCase(sl()));
  sl.registerLazySingleton(() => ChangePasswordUseCase(sl()));
  sl.registerLazySingleton(() => UploadAvatarUseCase(sl()));

  // Bloc
  sl.registerFactory(
    () => ProfileBloc(
      getUserProfile: sl(),
      updateUserProfile: sl(),
      changePassword: sl(),
      uploadAvatarUseCase: sl(),
    ),
  );

  // ==========================================
  // Clinical Notes Feature
  // ==========================================

  // Data source
  sl.registerLazySingleton<ClinicalNotesRemoteDataSource>(
    () => ClinicalNotesRemoteDataSourceImpl(client: sl()),
  );

  // Repository
  sl.registerLazySingleton<ClinicalNotesRepository>(
    () => ClinicalNotesRepositoryImpl(remoteDataSource: sl()),
  );

  // Use cases
  sl.registerLazySingleton(() => GetNotes(sl()));
  sl.registerLazySingleton(() => AddNote(sl()));
  sl.registerLazySingleton(() => UpdateNote(sl()));

  // Bloc
  sl.registerFactory(
    () => ClinicalNotesBloc(
      getNotes: sl(),
      addNote: sl(),
      updateNote: sl(),
    ),
  );

  // ==========================================
  // Cases Feature
  // ==========================================

  // Data source
  sl.registerLazySingleton<CasesRemoteDataSource>(
    () => CasesRemoteDataSourceImpl(client: sl()),
  );

  // Repository
  sl.registerLazySingleton<CaseRepository>(
    () => CaseRepositoryImpl(remoteDataSource: sl()),
  );

  // Use cases
  sl.registerLazySingleton(() => GetCasesUseCase(sl()));
  sl.registerLazySingleton(() => GetCaseDetailsUseCase(sl()));
  sl.registerLazySingleton(() => CreateCaseUseCase(sl()));
  sl.registerLazySingleton(() => UpdateCaseUseCase(sl()));
  sl.registerLazySingleton(() => DeleteCaseUseCase(sl()));

  // Bloc
  sl.registerFactory(
    () => CasesBloc(
      getCasesUseCase: sl(),
      createCaseUseCase: sl(),
      updateCaseUseCase: sl(),
    ),
  );

  // ==========================================
  // AI Feature
  // ==========================================

  sl.registerLazySingleton<AiRemoteDataSource>(
    () => AiRemoteDataSourceImpl(client: sl()),
  );

  // ==========================================
  // Reports Feature
  // ==========================================

  sl.registerLazySingleton<ReportsRemoteDataSource>(
    () => ReportsRemoteDataSourceImpl(client: sl()),
  );

  // ==========================================
  // Patients Feature
  // ==========================================

  // Data source
  sl.registerLazySingleton<PatientsRemoteDataSource>(
    () => PatientsRemoteDataSourceImpl(
      client: sl(),
      authLocalDataSource: sl(),
    ),
  );

  // Repository
  sl.registerLazySingleton<PatientRepository>(
    () => PatientRepositoryImpl(remoteDataSource: sl()),
  );

  // Use cases
  sl.registerLazySingleton(() => GetPatients(sl()));
  sl.registerLazySingleton(() => GetPatientById(sl()));
  sl.registerLazySingleton(() => AddPatient(sl()));
  sl.registerLazySingleton(() => UpdatePatient(sl()));
  sl.registerLazySingleton(() => DeletePatient(sl()));

  // Bloc
  sl.registerFactory(
    () => PatientBloc(
      getPatients: sl(),
      addPatient: sl(),
      updatePatient: sl(),
    ),
  );
}
