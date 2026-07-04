import 'dart:async';
import '../../features/auth/data/datasources/auth_local_data_source.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/models/auth_model.dart';

class TokenRefreshService {
  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;
  Timer? _timer;

  TokenRefreshService({
    required AuthRemoteDataSource remoteDataSource,
    required AuthLocalDataSource localDataSource,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 15), (_) => _refresh());
    _refresh();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _refresh() async {
    try {
      final auth = await _localDataSource.loadAuth();
      if (auth == null || auth.token.isEmpty || auth.refreshToken.isEmpty) return;

      final user = await _remoteDataSource.refreshToken(auth.token, auth.refreshToken);

      await _localDataSource.saveAuth(
        AuthModel(
          id: user.id,
          email: user.email,
          name: user.name,
          token: user.token,
          refreshToken: user.refreshToken,
        ),
      );
    } catch (_) {
      // Silently fail - token will be retried in 15 minutes
    }
  }
}
