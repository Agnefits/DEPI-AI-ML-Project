import 'package:flutter_bloc/flutter_bloc.dart';
import '../errors/error_handler.dart';

class AppBlocObserver extends BlocObserver {
  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    
    // Globally handle and log BLoC errors
    ErrorHandler.handleError(error, stackTrace, hint: 'Bloc: ${bloc.runtimeType}');
  }
}
