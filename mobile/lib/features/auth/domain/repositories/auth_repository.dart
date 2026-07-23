import 'package:sirasende_mobile/features/auth/data/models/login_request.dart';
import 'package:sirasende_mobile/features/auth/data/models/token_response.dart';
import 'package:sirasende_mobile/features/auth/domain/models/admin_user.dart';

abstract class AuthRepository {
  Future<TokenResponse> login(LoginRequest request);
  Future<AdminUser> getMe();
  Future<void> saveToken(String token);
  Future<String?> getToken();
  Future<void> deleteToken();
}
