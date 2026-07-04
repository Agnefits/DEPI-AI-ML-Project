import 'app_exception.dart';

class NoInternetException extends NetworkException {
  const NoInternetException({
    super.message = 'No internet connection. Please check your network and try again.',
    super.code = 'NO_INTERNET',
  });
}

class TimeoutException extends NetworkException {
  const TimeoutException({
    super.message = 'Connection timed out. Please try again later.',
    super.code = 'TIMEOUT',
  });
}
