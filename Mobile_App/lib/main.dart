import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/services/token_refresh_service.dart';
import 'core/services/app_bloc_observer.dart';
import 'core/errors/error_handler.dart';
import 'core/widgets/global_error_screen.dart';
import 'injection/injection_container.dart' as di;
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/data/datasources/auth_local_data_source.dart';
import 'features/auth/data/datasources/auth_remote_data_source.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await di.init();

    // 1. Handle Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      ErrorHandler.handleError(details.exception, details.stack, hint: 'FlutterError.onError');
    };

    // 2. Override default red error widget builder
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return GlobalErrorScreen(errorDetails: details);
    };

    // 3. Handle async errors globally
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      ErrorHandler.handleError(error, stack, hint: 'PlatformDispatcher.onError');
      return true;
    };

    // 4. Setup global BLoC observer
    Bloc.observer = AppBlocObserver();

    runApp(const ClinicApp());
  }, (Object error, StackTrace stack) {
    // 5. Catch any unhandled zone errors
    ErrorHandler.handleError(error, stack, hint: 'runZonedGuarded');
  });
}

class ClinicApp extends StatefulWidget {
  const ClinicApp({super.key});

  @override
  State<ClinicApp> createState() => _ClinicAppState();
}

class _ClinicAppState extends State<ClinicApp> {
  late final AuthBloc _authBloc;
  late final TokenRefreshService _tokenRefreshService;
  StreamSubscription? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authBloc = di.sl<AuthBloc>();
    _tokenRefreshService = TokenRefreshService(
      remoteDataSource: di.sl<AuthRemoteDataSource>(),
      localDataSource: di.sl<AuthLocalDataSource>(),
    );

    _authSubscription = _authBloc.stream.listen((state) {
      if (state is AuthAuthenticated) {
        _tokenRefreshService.start();
      } else if (state is AuthUnauthenticated) {
        _tokenRefreshService.stop();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _tokenRefreshService.stop();
    _authBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: _authBloc),
      ],
      child: MaterialApp.router(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        routerConfig: AppRouter.router,
      ),
    );
  }
}
