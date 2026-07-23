import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sirasende_mobile/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:sirasende_mobile/features/auth/data/models/login_request.dart';
import 'package:sirasende_mobile/features/auth/data/models/token_response.dart';
import 'package:sirasende_mobile/features/auth/domain/models/admin_user.dart';
import 'package:sirasende_mobile/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final FlutterSecureStorage _secureStorage;

  static const String _tokenKey = 'admin_jwt_token';

  AuthRepositoryImpl(this._remoteDataSource, this._secureStorage);

  @override
  Future<TokenResponse> login(LoginRequest request) {
    return _remoteDataSource.login(request);
  }

  @override
  Future<AdminUser> getMe() {
    return _remoteDataSource.getMe();
  }

  @override
  Future<void> saveToken(String token) {
    return _secureStorage.write(key: _tokenKey, value: token);
  }

  @override
  Future<String?> getToken() {
    return _secureStorage.read(key: _tokenKey);
  }

  @override
  Future<void> deleteToken() {
    return _secureStorage.delete(key: _tokenKey);
  }
}
