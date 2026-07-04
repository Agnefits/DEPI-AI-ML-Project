import '../services/logger_service.dart';
import 'exception_mapper.dart';
import 'failure.dart';

class ErrorHandler {
  /// Global centralized handler to capture and process errors
  static void handleError(Object error, StackTrace? stackTrace, {String? hint}) {
    final appException = ExceptionMapper.toAppException(error);
    
    // Log the error using LoggerService
    LoggerService.error(
      'Captured error: ${hint != null ? "[$hint] " : ""}$appException',
      error: error,
      stackTrace: stackTrace,
    );

    // Placeholder: Report to Firebase Crashlytics / Sentry in release mode
    _reportToCrashlytics(error, stackTrace, hint);
  }

  static void _reportToCrashlytics(Object error, StackTrace? stackTrace, String? hint) {
    // In production, you would run:
    // FirebaseCrashlytics.instance.recordError(error, stackTrace, reason: hint);
  }

  /// Maps an exception to a Failure and handles it silently (e.g. for repositories)
  static Failure handleRepositoryError(Object error, [StackTrace? stackTrace]) {
    handleError(error, stackTrace, hint: 'Repository Layer');
    return ExceptionMapper.toFailure(error);
  }
}
